import Foundation
import Combine

final class SessionManager: ObservableObject, SocketServerDelegate {
    static let shared = SessionManager()

    @Published private(set) var sessions: [Session] = []
    @Published private(set) var isConnected: Bool = false

    private var socketServer: SocketServer?
    private let configManager: ConfigurationManager
    private let notificationDispatcher: NotificationDispatcher

    private var staleSessionTimer: Timer?
    private let staleSessionCheckInterval: TimeInterval = 60.0 // Check every minute

    private let minWorkingDurationForNotification: TimeInterval = 30.0  // Only notify idle if worked > 30s

    var activeSessions: [Session] {
        sessions.filter { $0.state == .working || $0.state == .awaitingApproval || $0.state == .idle }
    }

    var recentCompletedSessions: [Session] {
        sessions.filter { session in
            guard session.state == .completed || session.state == .error || session.state == .idle else { return false }
            let hourAgo = Date().addingTimeInterval(-3600)
            return session.lastUpdateTime > hourAgo
        }
    }

    var hasAttentionNeeded: Bool {
        sessions.contains { $0.state.needsAttention }
    }

    var overallState: OverallState {
        if !isConnected {
            return .disconnected
        }

        if configManager.settings.isPaused {
            return .paused
        }

        if sessions.contains(where: { $0.state == .awaitingApproval }) {
            return .attention
        }

        if sessions.contains(where: { $0.state == .working }) {
            return .working
        }

        return .idle
    }

    enum OverallState {
        case disconnected
        case paused
        case idle
        case working
        case attention
    }

    private init() {
        configManager = ConfigurationManager.shared
        notificationDispatcher = NotificationDispatcher.shared

        startSocketServer()
        startStaleSessionCleanup()
    }

    func startSocketServer() {
        do {
            try configManager.ensureDirectoryExists()

            socketServer = SocketServer(socketPath: configManager.socketPath)
            socketServer?.delegate = self
            try socketServer?.start()
        } catch {
            print("Failed to start socket server: \(error)")
        }
    }

    func stopSocketServer() {
        socketServer?.stop()
        socketServer = nil
        isConnected = false
    }

    func restartSocketServer() {
        stopSocketServer()
        startSocketServer()
    }

    private func startStaleSessionCleanup() {
        staleSessionTimer = Timer.scheduledTimer(
            withTimeInterval: staleSessionCheckInterval,
            repeats: true
        ) { [weak self] _ in
            self?.cleanupStaleSessions()
        }
    }

    private func cleanupStaleSessions() {
        sessions.removeAll { $0.isStale }
    }

    // MARK: - SocketServerDelegate

    func socketServer(_ server: SocketServer, didReceiveMessage message: SocketMessage) {
        switch message {
        case .start(let sessionId, let tool, let projectName, let pid):
            handleSessionStart(sessionId: sessionId, tool: tool, projectName: projectName, pid: pid)

        case .state(let sessionId, let state, let details, let workingDurationSecs):
            handleSessionStateChange(sessionId: sessionId, state: state, details: details, workingDurationSecs: workingDurationSecs)

        case .end(let sessionId, let exitCode):
            handleSessionEnd(sessionId: sessionId, exitCode: exitCode)

        case .unknown(let raw):
            print("Unknown message: \(raw)")
        }
    }

    func socketServer(_ server: SocketServer, didChangeState isListening: Bool) {
        isConnected = isListening
    }

    // MARK: - Message Handlers

    private func handleSessionStart(sessionId: String, tool: String, projectName: String, pid: Int) {
        // Check if tool is enabled
        if tool == "claude" && !configManager.settings.tools.claude {
            return
        }
        if tool == "codex" && !configManager.settings.tools.codex {
            return
        }

        let session = Session(
            id: sessionId,
            tool: tool,
            projectName: projectName,
            pid: pid
        )

        // Remove any existing session with same ID
        sessions.removeAll { $0.id == sessionId }
        sessions.insert(session, at: 0)
    }

    private func handleSessionStateChange(sessionId: String, state: SessionState, details: String, workingDurationSecs: Int?) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else {
            return
        }

        let previousState = sessions[index].state
        sessions[index].updateState(state, details: details)

        // Trigger notification if state changed to something attention-worthy
        if state != previousState {
            triggerNotificationIfNeeded(for: sessions[index], previousState: previousState, workingDurationSecs: workingDurationSecs)
        }
    }

    private func handleSessionEnd(sessionId: String, exitCode: Int) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else {
            return
        }

        let previousState = sessions[index].state
        let newState: SessionState = exitCode == 0 ? .completed : .error
        sessions[index].updateState(newState, details: "Exit code: \(exitCode)")

        // Trigger notification
        triggerNotificationIfNeeded(for: sessions[index], previousState: previousState, workingDurationSecs: nil)
    }

    private func triggerNotificationIfNeeded(for session: Session, previousState: SessionState, workingDurationSecs: Int?) {
        // Don't notify if notifications are paused
        guard !configManager.settings.isPaused else { return }

        switch session.state {
        case .awaitingApproval:
            guard configManager.settings.notifications.approval.enabled else { return }
            notificationDispatcher.sendApprovalNeeded(session: session)

        case .completed:
            guard configManager.settings.notifications.completed.enabled else { return }
            // Only notify completion if it wasn't already awaiting approval
            // (user already knows about it)
            if previousState != .awaitingApproval {
                notificationDispatcher.sendCompleted(session: session)
            }

        case .error:
            guard configManager.settings.notifications.error.enabled else { return }
            notificationDispatcher.sendError(session: session)

        case .idle:
            // Only notify for idle if:
            // 1. Completed notifications are enabled (idle is similar to completed)
            // 2. Claude worked long enough to warrant notification (default 30s)
            // 3. The previous state was working (not transitioning from approval)
            guard configManager.settings.notifications.completed.enabled else { return }
            guard previousState == .working else { return }

            // Check if worked long enough for notification
            let workedLongEnough: Bool
            if let duration = workingDurationSecs {
                workedLongEnough = TimeInterval(duration) >= minWorkingDurationForNotification
            } else {
                // If we don't have duration info, assume it was long enough
                workedLongEnough = true
            }

            if workedLongEnough {
                notificationDispatcher.sendCompleted(session: session)
            }

        case .working:
            // No notification for working state
            break
        }
    }

    func clearCompletedSessions() {
        sessions.removeAll { $0.state == .completed || $0.state == .error || $0.state == .idle }
    }

    func removeSession(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
    }
}
