import Foundation

enum SocketMessage {
    case start(sessionId: String, tool: String, projectName: String, pid: Int)
    case state(sessionId: String, state: SessionState, details: String)
    case end(sessionId: String, exitCode: Int)
    case unknown(raw: String)

    private struct JsonMessage: Codable {
        let type: String
        let sessionId: String
        let tool: String?
        let projectName: String?
        let pid: Int?
        let state: String?
        let details: String?
        let exitCode: Int?

        enum CodingKeys: String, CodingKey {
            case type
            case sessionId = "session_id"
            case tool
            case projectName = "project_name"
            case pid
            case state
            case details
            case exitCode = "exit_code"
        }
    }

    static func parse(_ line: String) -> SocketMessage? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Try JSON parsing first
        if let data = trimmed.data(using: .utf8),
           let json = try? JSONDecoder().decode(JsonMessage.self, from: data) {
            return parseJson(json, raw: trimmed)
        }

        // Fallback to legacy pipe format for backwards compatibility during transition
        return parseLegacy(trimmed)
    }

    private static func parseJson(_ json: JsonMessage, raw: String) -> SocketMessage {
        switch json.type {
        case "START":
            guard let tool = json.tool,
                  let projectName = json.projectName,
                  let pid = json.pid else {
                return .unknown(raw: raw)
            }
            return .start(
                sessionId: json.sessionId,
                tool: tool,
                projectName: projectName,
                pid: pid
            )

        case "STATE":
            guard let stateStr = json.state,
                  let state = SessionState(rawValue: stateStr) else {
                return .unknown(raw: raw)
            }
            return .state(
                sessionId: json.sessionId,
                state: state,
                details: json.details ?? ""
            )

        case "END":
            guard let exitCode = json.exitCode else {
                return .unknown(raw: raw)
            }
            return .end(
                sessionId: json.sessionId,
                exitCode: exitCode
            )

        default:
            return .unknown(raw: raw)
        }
    }

    // Legacy pipe-delimited format parser for backwards compatibility
    private static func parseLegacy(_ trimmed: String) -> SocketMessage {
        let parts = trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0) }

        guard let messageType = parts.first else {
            return .unknown(raw: trimmed)
        }

        switch messageType {
        case "START":
            guard parts.count >= 5,
                  let pid = Int(parts[4]) else {
                return .unknown(raw: trimmed)
            }
            return .start(
                sessionId: parts[1],
                tool: parts[2],
                projectName: parts[3],
                pid: pid
            )

        case "STATE":
            guard parts.count >= 4,
                  let state = SessionState(rawValue: parts[2]) else {
                return .unknown(raw: trimmed)
            }
            let details = parts[3].replacingOccurrences(of: "\\|", with: "|")
            return .state(
                sessionId: parts[1],
                state: state,
                details: details
            )

        case "END":
            guard parts.count >= 3,
                  let exitCode = Int(parts[2]) else {
                return .unknown(raw: trimmed)
            }
            return .end(
                sessionId: parts[1],
                exitCode: exitCode
            )

        default:
            return .unknown(raw: trimmed)
        }
    }
}
