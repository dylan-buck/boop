import SwiftUI

struct SessionRowView: View {
    let session: Session

    var body: some View {
        HStack(spacing: 8) {
            // State indicator
            Image(systemName: session.state.icon)
                .foregroundColor(session.state.color)
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 2) {
                // Project name
                Text(session.projectName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                // Status line
                HStack(spacing: 4) {
                    Text(session.tool.capitalized)
                        .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(.secondary)

                    Text(statusText)
                        .foregroundColor(statusColor)
                }
                .font(.system(size: 11))
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }

    private var statusText: String {
        switch session.state {
        case .working:
            return "Working · \(session.formattedDuration)"
        case .awaitingApproval:
            return "Waiting for approval"
        case .idle:
            return "Ready · \(session.timeSinceUpdate)"
        case .completed:
            return "Completed · \(session.timeSinceUpdate)"
        case .error:
            return "Error"
        }
    }

    private var statusColor: Color {
        switch session.state {
        case .awaitingApproval:
            return .orange
        case .error:
            return .red
        default:
            return .secondary
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        SessionRowView(session: Session(
            id: "1",
            tool: "claude",
            projectName: "my-api-project",
            pid: 12345
        ))

        Divider()

        SessionRowView(session: {
            var session = Session(
                id: "2",
                tool: "codex",
                projectName: "frontend-app",
                pid: 12346
            )
            session.updateState(.awaitingApproval, details: "Waiting for approval")
            return session
        }())

        Divider()

        SessionRowView(session: {
            var session = Session(
                id: "3",
                tool: "claude",
                projectName: "backend-service",
                pid: 12347
            )
            session.updateState(.completed, details: "Done")
            return session
        }())
    }
    .frame(width: 280)
    .padding()
}
