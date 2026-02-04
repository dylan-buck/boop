import Foundation

enum ShellType: String, CaseIterable {
    case zsh
    case bash

    var configFile: String {
        switch self {
        case .zsh:
            return ".zshrc"
        case .bash:
            return ".bashrc"
        }
    }

    var hookFile: String {
        switch self {
        case .zsh:
            return "hook.zsh"
        case .bash:
            return "hook.bash"
        }
    }

    var sourceLine: String {
        "source \"$HOME/.boop/\(hookFile)\""
    }

    var sourceLineWithComment: String {
        "\n# Boop shell integration\n\(sourceLine)\n"
    }
}

enum ShellIntegrationStatus {
    case notInstalled
    case installed
    case partial(installed: [ShellType], missing: [ShellType])
    case missingBinary
    case error(String)

    var isFullyFunctional: Bool {
        if case .installed = self {
            return true
        }
        return false
    }
}

final class ShellIntegrationService: ObservableObject {
    static let shared = ShellIntegrationService()

    @Published private(set) var status: ShellIntegrationStatus = .notInstalled
    @Published private(set) var detectedShell: ShellType = .zsh
    @Published private(set) var isPTYBinaryInstalled: Bool = false

    private let configManager: ConfigurationManager
    private let fileManager = FileManager.default

    private init() {
        configManager = ConfigurationManager.shared
        detectCurrentShell()
        refreshStatus()
    }

    private var homeDirectory: URL {
        fileManager.homeDirectoryForCurrentUser
    }

    private var boopDirectory: URL {
        configManager.boopDirectory
    }

    private var ptyBinaryPath: URL {
        configManager.binDirectory.appendingPathComponent("boop-pty")
    }

    private func detectCurrentShell() {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        if shell.contains("bash") {
            detectedShell = .bash
        } else {
            detectedShell = .zsh
        }
    }

    func refreshStatus() {
        // Check if PTY binary exists
        isPTYBinaryInstalled = fileManager.fileExists(atPath: ptyBinaryPath.path)

        var installed: [ShellType] = []
        var missing: [ShellType] = []

        for shellType in ShellType.allCases {
            if isHookInstalledIn(shell: shellType) {
                installed.append(shellType)
            } else {
                missing.append(shellType)
            }
        }

        // Check if hooks are installed but binary is missing
        if !installed.isEmpty && !isPTYBinaryInstalled {
            status = .missingBinary
        } else if installed.isEmpty {
            status = .notInstalled
        } else if missing.isEmpty {
            status = .installed
        } else {
            status = .partial(installed: installed, missing: missing)
        }
    }

    private func isHookInstalledIn(shell: ShellType) -> Bool {
        let configPath = homeDirectory.appendingPathComponent(shell.configFile)

        guard let content = try? String(contentsOf: configPath, encoding: .utf8) else {
            return false
        }

        return content.contains(".boop/hook")
    }

    func installHooks(for shell: ShellType? = nil) throws {
        // Copy hook files from bundle to ~/.boop/
        try copyHookFiles()

        // Copy PTY binary from bundle to ~/.boop/bin/
        try copyPTYBinary()

        // Install in specified shell or detected shell
        let targetShell = shell ?? detectedShell
        try installHookIn(shell: targetShell)

        refreshStatus()
    }

    func installAllHooks() throws {
        try copyHookFiles()
        try copyPTYBinary()

        for shellType in ShellType.allCases {
            try? installHookIn(shell: shellType)
        }

        refreshStatus()
    }

    private func copyHookFiles() throws {
        try configManager.ensureDirectoryExists()

        for shellType in ShellType.allCases {
            guard let bundlePath = Bundle.main.path(forResource: shellType.hookFile, ofType: nil) else {
                throw ShellIntegrationError.hookFileNotFound(shellType.hookFile)
            }

            let destinationPath = boopDirectory.appendingPathComponent(shellType.hookFile)

            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationPath.path) {
                try fileManager.removeItem(at: destinationPath)
            }

            try fileManager.copyItem(
                atPath: bundlePath,
                toPath: destinationPath.path
            )

            // Make executable
            try fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: destinationPath.path
            )
        }
    }

    private func copyPTYBinary() throws {
        let binDirectory = configManager.binDirectory

        try fileManager.createDirectory(
            at: binDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let destinationPath = binDirectory.appendingPathComponent("boop-pty")

        // Look for boop-pty in the app bundle's MacOS directory (bundled during build)
        if let executableURL = Bundle.main.executableURL {
            let bundledBinaryPath = executableURL
                .deletingLastPathComponent()
                .appendingPathComponent("boop-pty")

            if fileManager.fileExists(atPath: bundledBinaryPath.path) {
                // Remove existing file if present
                if fileManager.fileExists(atPath: destinationPath.path) {
                    try fileManager.removeItem(at: destinationPath)
                }

                try fileManager.copyItem(at: bundledBinaryPath, to: destinationPath)

                // Make executable
                try fileManager.setAttributes(
                    [.posixPermissions: 0o755],
                    ofItemAtPath: destinationPath.path
                )

                isPTYBinaryInstalled = true
                return
            }
        }

        // Fallback: Look in Resources (legacy location)
        if let bundlePath = Bundle.main.path(forResource: "boop-pty", ofType: nil) {
            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationPath.path) {
                try fileManager.removeItem(at: destinationPath)
            }

            try fileManager.copyItem(
                atPath: bundlePath,
                toPath: destinationPath.path
            )

            // Make executable
            try fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: destinationPath.path
            )

            isPTYBinaryInstalled = true
            return
        }

        // Development fallback: check if binary exists in typical build locations
        let devPaths = [
            homeDirectory.appendingPathComponent("Documents/GitHub/boop/boop-pty/target/release/boop-pty"),
            homeDirectory.appendingPathComponent("Documents/GitHub/boop/boop-pty/target/debug/boop-pty"),
        ]

        for devPath in devPaths {
            if fileManager.fileExists(atPath: devPath.path) {
                if fileManager.fileExists(atPath: destinationPath.path) {
                    try fileManager.removeItem(at: destinationPath)
                }

                try fileManager.copyItem(at: devPath, to: destinationPath)
                try fileManager.setAttributes(
                    [.posixPermissions: 0o755],
                    ofItemAtPath: destinationPath.path
                )

                isPTYBinaryInstalled = true
                print("Installed boop-pty from development build: \(devPath.path)")
                return
            }
        }

        // Binary not found anywhere
        print("Warning: boop-pty binary not found in bundle or development paths")
        print("The shell hooks will fall back to running commands without monitoring")
        isPTYBinaryInstalled = false
    }

    private func installHookIn(shell: ShellType) throws {
        let configPath = homeDirectory.appendingPathComponent(shell.configFile)

        // Read existing content or create empty
        var content: String
        if fileManager.fileExists(atPath: configPath.path) {
            content = try String(contentsOf: configPath, encoding: .utf8)

            // Check if already installed
            if content.contains(".boop/hook") {
                return // Already installed
            }
        } else {
            content = ""
        }

        // Append hook source line
        content += shell.sourceLineWithComment

        try content.write(to: configPath, atomically: true, encoding: .utf8)
    }

    func uninstallHooks() throws {
        for shellType in ShellType.allCases {
            try uninstallHookFrom(shell: shellType)
        }

        refreshStatus()
    }

    func uninstallHookFrom(shell: ShellType) throws {
        let configPath = homeDirectory.appendingPathComponent(shell.configFile)

        guard fileManager.fileExists(atPath: configPath.path) else {
            return
        }

        var content = try String(contentsOf: configPath, encoding: .utf8)

        // Remove the Boop integration lines
        let lines = content.components(separatedBy: "\n")
        var filteredLines: [String] = []
        var skipNext = false

        for line in lines {
            if skipNext {
                skipNext = false
                continue
            }

            if line.contains("# Boop shell integration") {
                skipNext = true
                continue
            }

            if line.contains(".boop/hook") {
                continue
            }

            filteredLines.append(line)
        }

        content = filteredLines.joined(separator: "\n")

        // Clean up extra blank lines at the end
        while content.hasSuffix("\n\n") {
            content.removeLast()
        }

        try content.write(to: configPath, atomically: true, encoding: .utf8)
    }

    var installationInstructions: String {
        """
        Add this line to your \(detectedShell.configFile):

        \(detectedShell.sourceLine)

        Then restart your terminal or run:
        source ~/\(detectedShell.configFile)
        """
    }
}

enum ShellIntegrationError: LocalizedError {
    case hookFileNotFound(String)
    case configFileNotWritable(String)
    case binaryNotFound

    var errorDescription: String? {
        switch self {
        case .hookFileNotFound(let file):
            return "Hook file not found: \(file)"
        case .configFileNotWritable(let file):
            return "Cannot write to config file: \(file)"
        case .binaryNotFound:
            return "boop-pty binary not found. Please rebuild and install."
        }
    }
}
