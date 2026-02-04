import Foundation

enum NotificationPriority: String, Codable, CaseIterable {
    case min = "min"
    case low = "low"
    case `default` = "default"
    case high = "high"
    case urgent = "urgent"

    var displayName: String {
        switch self {
        case .min:
            return "Min"
        case .low:
            return "Low"
        case .default:
            return "Default"
        case .high:
            return "High"
        case .urgent:
            return "Urgent"
        }
    }

    var ntfyValue: Int {
        switch self {
        case .min:
            return 1
        case .low:
            return 2
        case .default:
            return 3
        case .high:
            return 4
        case .urgent:
            return 5
        }
    }
}

struct NotificationSettings: Codable, Equatable {
    var enabled: Bool
    var priority: NotificationPriority

    static let defaultApproval = NotificationSettings(enabled: true, priority: .urgent)
    static let defaultCompleted = NotificationSettings(enabled: true, priority: .default)
    static let defaultError = NotificationSettings(enabled: true, priority: .high)
}

struct NtfySettings: Codable, Equatable {
    var topic: String
    var server: String

    static let defaultServer = "https://ntfy.sh"

    static func withRandomTopic() -> NtfySettings {
        return NtfySettings(
            topic: TopicGenerator.generate(),
            server: defaultServer
        )
    }
}

struct QuietHours: Codable, Equatable {
    var enabled: Bool
    var start: String // HH:mm format
    var end: String   // HH:mm format

    static let `default` = QuietHours(enabled: false, start: "22:00", end: "08:00")

    var isCurrentlyActive: Bool {
        guard enabled else { return false }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard let startTime = formatter.date(from: start),
              let endTime = formatter.date(from: end) else {
            return false
        }

        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)

        let startHour = calendar.component(.hour, from: startTime)
        let startMinute = calendar.component(.minute, from: startTime)
        let endHour = calendar.component(.hour, from: endTime)
        let endMinute = calendar.component(.minute, from: endTime)

        let currentMinutes = currentHour * 60 + currentMinute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        if startMinutes < endMinutes {
            // Same day range (e.g., 09:00 - 17:00)
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        } else {
            // Overnight range (e.g., 22:00 - 08:00)
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        }
    }
}

struct ToolSettings: Codable, Equatable {
    var claude: Bool
    var codex: Bool

    static let `default` = ToolSettings(claude: true, codex: true)
}

struct AppSettings: Codable, Equatable {
    var version: Int
    var ntfy: NtfySettings
    var notifications: NotificationPreferences
    var tools: ToolSettings
    var quietHours: QuietHours
    var respectDND: Bool
    var launchAtLogin: Bool
    var onboardingComplete: Bool
    var isPaused: Bool

    struct NotificationPreferences: Codable, Equatable {
        var approval: NotificationSettings
        var completed: NotificationSettings
        var error: NotificationSettings
    }

    static let `default` = AppSettings(
        version: 1,
        ntfy: .withRandomTopic(),
        notifications: NotificationPreferences(
            approval: .defaultApproval,
            completed: .defaultCompleted,
            error: .defaultError
        ),
        tools: .default,
        quietHours: .default,
        respectDND: true,
        launchAtLogin: true,
        onboardingComplete: false,
        isPaused: false
    )

    var ntfySubscribeURL: String {
        "\(ntfy.server)/\(ntfy.topic)"
    }
}
