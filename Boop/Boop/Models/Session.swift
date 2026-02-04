import Foundation

struct Session: Identifiable, Codable, Equatable {
    let id: String
    let tool: String
    let projectName: String
    let pid: Int
    var state: SessionState
    var details: String
    let startTime: Date
    var lastUpdateTime: Date

    init(id: String, tool: String, projectName: String, pid: Int) {
        self.id = id
        self.tool = tool
        self.projectName = projectName
        self.pid = pid
        self.state = .working
        self.details = ""
        self.startTime = Date()
        self.lastUpdateTime = Date()
    }

    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }

    var timeSinceUpdate: String {
        let interval = Date().timeIntervalSince(lastUpdateTime)
        let minutes = Int(interval) / 60

        if minutes < 1 {
            return "just now"
        } else if minutes == 1 {
            return "1m ago"
        } else {
            return "\(minutes)m ago"
        }
    }

    var isStale: Bool {
        let staleThreshold: TimeInterval = 24 * 60 * 60 // 24 hours
        return Date().timeIntervalSince(lastUpdateTime) > staleThreshold
    }

    mutating func updateState(_ newState: SessionState, details: String = "") {
        self.state = newState
        self.details = details
        self.lastUpdateTime = Date()
    }
}
