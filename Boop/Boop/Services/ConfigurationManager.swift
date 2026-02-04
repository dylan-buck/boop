import Foundation
import Combine

final class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()

    @Published var settings: AppSettings

    private let configDirectory: URL
    private let configFile: URL
    private var saveDebouncer: AnyCancellable?

    private init() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        configDirectory = homeDirectory.appendingPathComponent(".boop")
        configFile = configDirectory.appendingPathComponent("config.json")

        // Load settings or use defaults
        if let loaded = ConfigurationManager.loadSettings(from: configFile) {
            settings = loaded
        } else {
            settings = .default
        }

        // Set up auto-save on changes
        saveDebouncer = $settings
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] newSettings in
                self?.saveSettings(newSettings)
            }
    }

    private static func loadSettings(from url: URL) -> AppSettings? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(AppSettings.self, from: data)
        } catch {
            print("Failed to load settings: \(error)")
            return nil
        }
    }

    private func saveSettings(_ settings: AppSettings) {
        do {
            // Ensure directory exists
            try FileManager.default.createDirectory(
                at: configDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: configFile, options: .atomic)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }

    func resetToDefaults() {
        settings = .default
        settings.ntfy = .withRandomTopic()
    }

    func regenerateTopic() {
        settings.ntfy.topic = TopicGenerator.generate()
    }

    func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: configDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    var boopDirectory: URL {
        configDirectory
    }

    var socketPath: URL {
        configDirectory.appendingPathComponent("sock")
    }

    var binDirectory: URL {
        configDirectory.appendingPathComponent("bin")
    }
}
