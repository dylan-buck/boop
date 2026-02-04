import SwiftUI

struct MenuBarIcon: View {
    let state: SessionManager.OverallState

    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
    }

    private var iconName: String {
        switch state {
        case .paused:
            return "pause.circle.fill"
        case .disconnected:
            return "circle"
        default:
            return "circle.fill"
        }
    }

    private var iconColor: Color {
        switch state {
        case .idle:
            return .green
        case .working:
            return .blue
        case .attention:
            return .orange
        case .disconnected:
            return .gray
        case .paused:
            return .gray
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            MenuBarIcon(state: .idle)
            Text("Idle")
        }
        HStack(spacing: 20) {
            MenuBarIcon(state: .working)
            Text("Working")
        }
        HStack(spacing: 20) {
            MenuBarIcon(state: .attention)
            Text("Attention")
        }
        HStack(spacing: 20) {
            MenuBarIcon(state: .disconnected)
            Text("Disconnected")
        }
        HStack(spacing: 20) {
            MenuBarIcon(state: .paused)
            Text("Paused")
        }
    }
    .padding()
}
