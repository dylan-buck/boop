import Foundation

final class NotificationDispatcher: ObservableObject {
    static let shared = NotificationDispatcher()

    @Published private(set) var lastError: String?
    @Published private(set) var isTestingConnection: Bool = false
    @Published private(set) var lastSuccessfulSend: Date?
    @Published private(set) var connectionHealthy: Bool = false

    private let configManager: ConfigurationManager
    private let dndChecker: DNDChecker
    private var debounceTimers: [String: Date] = [:]
    private let debounceInterval: TimeInterval = 30.0
    private var healthCheckTimer: Timer?

    private init() {
        configManager = ConfigurationManager.shared
        dndChecker = DNDChecker.shared
        startHealthCheckTimer()
    }

    private func startHealthCheckTimer() {
        // Check ntfy health every 60 seconds
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task {
                await self?.checkHealth()
            }
        }
        // Also check immediately on startup
        Task {
            await checkHealth()
        }
    }

    func checkHealth() async {
        let settings = configManager.settings.ntfy

        guard let url = URL(string: settings.server) else {
            await MainActor.run { connectionHealthy = false }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let healthy = (response as? HTTPURLResponse)?.statusCode == 200
            await MainActor.run { connectionHealthy = healthy }
        } catch {
            await MainActor.run { connectionHealthy = false }
        }
    }

    func sendApprovalNeeded(session: Session) {
        let settings = configManager.settings.notifications.approval
        send(
            title: session.projectName,
            message: "\(session.tool.capitalized) is waiting for approval",
            priority: settings.priority,
            tags: ["warning"],
            sessionId: session.id
        )
    }

    func sendCompleted(session: Session) {
        let settings = configManager.settings.notifications.completed
        send(
            title: session.projectName,
            message: "\(session.tool.capitalized) finished",
            priority: settings.priority,
            tags: ["white_check_mark"],
            sessionId: session.id
        )
    }

    func sendError(session: Session) {
        let settings = configManager.settings.notifications.error
        send(
            title: session.projectName,
            message: "\(session.tool.capitalized) encountered an error",
            priority: settings.priority,
            tags: ["x"],
            sessionId: session.id
        )
    }

    func sendTestNotification() async -> Bool {
        await MainActor.run {
            isTestingConnection = true
            lastError = nil
        }

        defer {
            Task { @MainActor in
                isTestingConnection = false
            }
        }

        return await sendAsync(
            title: "Boop Test",
            message: "If you see this, notifications are working!",
            priority: .default,
            tags: ["tada"],
            bypassChecks: true
        )
    }

    private func send(
        title: String,
        message: String,
        priority: NotificationPriority,
        tags: [String],
        sessionId: String
    ) {
        // Check debounce
        if let lastSent = debounceTimers[sessionId],
           Date().timeIntervalSince(lastSent) < debounceInterval {
            print("Debouncing notification for session \(sessionId)")
            return
        }

        // Check quiet hours
        if configManager.settings.quietHours.isCurrentlyActive {
            print("Quiet hours active - skipping notification")
            return
        }

        // Check DND if enabled
        if configManager.settings.respectDND && dndChecker.isDoNotDisturbEnabled {
            print("Do Not Disturb enabled - skipping notification")
            return
        }

        debounceTimers[sessionId] = Date()

        Task {
            await sendAsync(
                title: title,
                message: message,
                priority: priority,
                tags: tags,
                bypassChecks: false
            )
        }
    }

    @discardableResult
    private func sendAsync(
        title: String,
        message: String,
        priority: NotificationPriority,
        tags: [String],
        bypassChecks: Bool
    ) async -> Bool {
        let settings = configManager.settings.ntfy

        guard let url = URL(string: "\(settings.server)/\(settings.topic)") else {
            await MainActor.run {
                lastError = "Invalid ntfy URL"
            }
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(title, forHTTPHeaderField: "Title")
        request.setValue(String(priority.ntfyValue), forHTTPHeaderField: "Priority")
        request.setValue(tags.joined(separator: ","), forHTTPHeaderField: "Tags")
        request.httpBody = message.data(using: .utf8)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    lastError = "Invalid response"
                }
                return false
            }

            if httpResponse.statusCode == 200 {
                await MainActor.run {
                    lastError = nil
                    lastSuccessfulSend = Date()
                    connectionHealthy = true
                }
                return true
            } else {
                await MainActor.run {
                    lastError = "HTTP \(httpResponse.statusCode)"
                }
                return false
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
            return false
        }
    }

    func clearDebounce(for sessionId: String) {
        debounceTimers.removeValue(forKey: sessionId)
    }

    func clearAllDebounce() {
        debounceTimers.removeAll()
    }
}
