import Foundation
import Network

protocol SocketServerDelegate: AnyObject {
    func socketServer(_ server: SocketServer, didReceiveMessage message: SocketMessage)
    func socketServer(_ server: SocketServer, didChangeState isListening: Bool)
}

final class SocketServer {
    weak var delegate: SocketServerDelegate?

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var connectionBuffers: [ObjectIdentifier: String] = [:]
    private let queue = DispatchQueue(label: "com.boop.socketserver")
    private let socketPath: URL

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
        // Remove existing socket file if present
        let path = socketPath.path
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }

        // Ensure parent directory exists
        let parentDir = socketPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parentDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Create Unix socket endpoint
        let endpoint = NWEndpoint.unix(path: path)

        // Create parameters for local connections only
        let parameters = NWParameters()
        parameters.allowLocalEndpointReuse = true
        parameters.requiredLocalEndpoint = endpoint

        // Create listener
        listener = try NWListener(using: parameters)

        listener?.stateUpdateHandler = { [weak self] state in
            self?.handleListenerState(state)
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: queue)

        // Set file permissions to 0600 (owner read/write only)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: path
        )
    }

    func stop() {
        listener?.cancel()
        listener = nil

        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
        connectionBuffers.removeAll()

        // Clean up socket file
        if FileManager.default.fileExists(atPath: socketPath.path) {
            try? FileManager.default.removeItem(atPath: socketPath.path)
        }

        isListening = false
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            isListening = true
            print("Socket server listening on \(socketPath.path)")

        case .failed(let error):
            isListening = false
            print("Socket server failed: \(error)")
            // Try to restart after a delay
            queue.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                try? self?.start()
            }

        case .cancelled:
            isListening = false
            print("Socket server cancelled")

        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        let connectionId = ObjectIdentifier(connection)
        connections.append(connection)
        connectionBuffers[connectionId] = ""

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveData(from: connection)

            case .failed, .cancelled:
                self?.removeConnection(connection)

            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.processData(data, from: connection)
            }

            if isComplete || error != nil {
                self?.removeConnection(connection)
            } else {
                // Continue receiving
                self?.receiveData(from: connection)
            }
        }
    }

    private func processData(_ data: Data, from connection: NWConnection) {
        guard let string = String(data: data, encoding: .utf8) else { return }

        let connectionId = ObjectIdentifier(connection)

        // Append to buffer for this connection
        var buffer = connectionBuffers[connectionId] ?? ""
        buffer += string

        // Process complete lines
        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newlineIndex])
            buffer = String(buffer[buffer.index(after: newlineIndex)...])

            if let message = SocketMessage.parse(line) {
                DispatchQueue.main.async {
                    self.delegate?.socketServer(self, didReceiveMessage: message)
                }
            }
        }

        // Store remaining partial line
        connectionBuffers[connectionId] = buffer
    }

    private func removeConnection(_ connection: NWConnection) {
        let connectionId = ObjectIdentifier(connection)
        connections.removeAll { $0 === connection }
        connectionBuffers.removeValue(forKey: connectionId)
        connection.cancel()
    }
}
