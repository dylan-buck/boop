import Foundation

protocol SocketServerDelegate: AnyObject {
    func socketServer(_ server: SocketServer, didReceiveMessage message: SocketMessage)
    func socketServer(_ server: SocketServer, didChangeState isListening: Bool)
}

final class SocketServer {
    weak var delegate: SocketServerDelegate?

    private var serverSocket: Int32 = -1
    private var acceptThread: Thread?
    private var isRunning = false
    private let socketPath: URL
    private let queue = DispatchQueue(label: "com.boop.socketserver")

    private(set) var isListening: Bool = false {
        didSet {
            if oldValue != isListening {
                DispatchQueue.main.async {
                    self.delegate?.socketServer(self, didChangeState: self.isListening)
                }
            }
        }
    }

    init(socketPath: URL) {
        self.socketPath = socketPath
    }

    func start() throws {
        let path = socketPath.path

        // Ensure parent directory exists
        let parentDir = socketPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parentDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Remove existing socket file if present
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }

        // Create Unix domain socket
        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw SocketError.createFailed(errno: errno)
        }

        // Set socket options
        var reuseAddr: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))

        // Bind to path
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = path.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            Darwin.close(serverSocket)
            throw SocketError.pathTooLong
        }

        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                for (i, byte) in pathBytes.enumerated() {
                    dest[i] = byte
                }
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(serverSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            let err = errno
            Darwin.close(serverSocket)
            throw SocketError.bindFailed(errno: err)
        }

        // Set file permissions to 0600 (owner read/write only)
        chmod(path, 0o600)

        // Listen for connections
        guard listen(serverSocket, 5) == 0 else {
            let err = errno
            Darwin.close(serverSocket)
            throw SocketError.listenFailed(errno: err)
        }

        isRunning = true
        isListening = true
        print("Socket server listening on \(path)")

        // Start accept loop in background thread
        acceptThread = Thread { [weak self] in
            self?.acceptLoop()
        }
        acceptThread?.name = "BoopSocketAccept"
        acceptThread?.start()
    }

    func stop() {
        isRunning = false

        if serverSocket >= 0 {
            Darwin.close(serverSocket)
            serverSocket = -1
        }

        // Clean up socket file
        if FileManager.default.fileExists(atPath: socketPath.path) {
            try? FileManager.default.removeItem(atPath: socketPath.path)
        }

        isListening = false
    }

    private func acceptLoop() {
        while isRunning && serverSocket >= 0 {
            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    accept(serverSocket, sockaddrPtr, &clientAddrLen)
                }
            }

            guard clientSocket >= 0 else {
                if isRunning {
                    // Accept failed but we're still running - might be temporary
                    Thread.sleep(forTimeInterval: 0.1)
                }
                continue
            }

            // Handle client in separate queue
            queue.async { [weak self] in
                self?.handleClient(socket: clientSocket)
            }
        }
    }

    private func handleClient(socket clientSocket: Int32) {
        defer {
            Darwin.close(clientSocket)
        }

        var buffer = [UInt8](repeating: 0, count: 4096)
        var lineBuffer = ""

        while isRunning {
            let bytesRead = read(clientSocket, &buffer, buffer.count)

            if bytesRead <= 0 {
                break
            }

            if let chunk = String(bytes: buffer[0..<bytesRead], encoding: .utf8) {
                lineBuffer += chunk

                // Process complete lines
                while let newlineIndex = lineBuffer.firstIndex(of: "\n") {
                    let line = String(lineBuffer[..<newlineIndex])
                    lineBuffer = String(lineBuffer[lineBuffer.index(after: newlineIndex)...])

                    if let message = SocketMessage.parse(line) {
                        DispatchQueue.main.async {
                            self.delegate?.socketServer(self, didReceiveMessage: message)
                        }
                    }
                }
            }
        }
    }

    deinit {
        stop()
    }
}

enum SocketError: LocalizedError {
    case createFailed(errno: Int32)
    case bindFailed(errno: Int32)
    case listenFailed(errno: Int32)
    case pathTooLong

    var errorDescription: String? {
        switch self {
        case .createFailed(let err):
            return "Failed to create socket: \(String(cString: strerror(err)))"
        case .bindFailed(let err):
            return "Failed to bind socket: \(String(cString: strerror(err)))"
        case .listenFailed(let err):
            return "Failed to listen on socket: \(String(cString: strerror(err)))"
        case .pathTooLong:
            return "Socket path is too long"
        }
    }
}
