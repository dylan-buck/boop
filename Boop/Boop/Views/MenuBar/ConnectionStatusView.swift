import SwiftUI

struct ConnectionStatusView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var notificationDispatcher = NotificationDispatcher.shared

    var body: some View {
        HStack(spacing: 6) {
            if !configManager.settings.onboardingComplete {
                Image(systemName: "iphone.badge.exclamationmark")
                    .foregroundColor(.orange)
                Text("Set up phone notifications")
                    .foregroundColor(.primary)
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))
            } else {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(statusText)
                        .foregroundColor(.secondary)
                    if let lastSent = notificationDispatcher.lastSuccessfulSend {
                        Text("Last sent: \(timeAgo(lastSent))")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 10))
            }
        }
        .font(.system(size: 12))
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
    }

    private var statusIcon: String {
        if !sessionManager.isConnected {
            return "antenna.radiowaves.left.and.right.slash"
        } else if notificationDispatcher.connectionHealthy {
            return "iphone"
        } else {
            return "iphone.slash"
        }
    }

    private var statusColor: Color {
        if !sessionManager.isConnected {
            return .red
        } else if notificationDispatcher.lastError != nil {
            return .orange
        } else if notificationDispatcher.connectionHealthy {
            return .green
        } else {
            return .orange
        }
    }

    private var statusText: String {
        if !sessionManager.isConnected {
            return "Socket disconnected"
        } else if let error = notificationDispatcher.lastError {
            return "ntfy: \(error)"
        } else if notificationDispatcher.connectionHealthy {
            return "ntfy ready"
        } else {
            return "Checking ntfy..."
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ConnectionStatusView(
            sessionManager: SessionManager.shared,
            configManager: ConfigurationManager.shared
        )
    }
    .padding()
}
