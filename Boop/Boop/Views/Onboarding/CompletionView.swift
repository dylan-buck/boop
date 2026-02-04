import SwiftUI

struct CompletionView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            // Title
            Text("You're all set!")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Subtitle
            Text("Boop is running in your menu bar")
                .font(.title3)
                .foregroundColor(.secondary)

            // Menu bar indicator
            VStack(spacing: 8) {
                Image(systemName: "circle.fill")
                    .font(.title)
                    .foregroundColor(.green)

                Text("Look for this icon")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Image(systemName: "arrow.up")
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Next steps
            VStack(alignment: .leading, spacing: 16) {
                Text("Next steps:")
                    .font(.headline)

                NextStepRow(
                    icon: "terminal.fill",
                    text: "Open a new terminal window"
                )

                NextStepRow(
                    icon: "command",
                    text: "Run `claude` or `codex` as usual"
                )

                NextStepRow(
                    icon: "figure.walk",
                    text: "Walk away - we'll ping you when it's ready"
                )
            }
            .padding(.horizontal, 60)

            Spacer()

            // Finish button
            Button(action: onFinish) {
                Text("Close & Start Using")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NextStepRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    CompletionView(onFinish: {})
        .frame(width: 500, height: 600)
}
