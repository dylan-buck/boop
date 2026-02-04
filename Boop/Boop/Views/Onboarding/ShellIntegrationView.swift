import SwiftUI

struct ShellIntegrationView: View {
    let onContinue: () -> Void
    let onBack: () -> Void

    @ObservedObject var shellService = ShellIntegrationService.shared

    @State private var isInstalling = false
    @State private var installError: String?
    @State private var showFullChanges = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("Enable CLI Monitoring")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Description
            Text("Boop needs to add a hook to your shell to detect when Claude and Codex need your attention.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Code preview
            VStack(alignment: .leading, spacing: 8) {
                Text("This adds one line to ~/.\(shellService.detectedShell.rawValue)rc:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(shellService.detectedShell.sourceLine)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 40)

            // Action buttons
            HStack(spacing: 16) {
                Button("View Full Changes") {
                    showFullChanges = true
                }

                Button(action: installHooks) {
                    HStack {
                        if isInstalling {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Install Automatically")
                    }
                }
                .disabled(isInstalling)
            }

            if let error = installError {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            }

            // Warning
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Restart your terminal after installation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 40)

            Spacer()

            // Navigation buttons
            HStack {
                Button("Back") {
                    onBack()
                }

                Spacer()

                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showFullChanges) {
            fullChangesSheet
        }
    }

    private var fullChangesSheet: some View {
        VStack(spacing: 16) {
            Text("Shell Hook Details")
                .font(.headline)

            ScrollView {
                Text(hookContent)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
            .frame(maxHeight: 400)

            Button("Close") {
                showFullChanges = false
            }
        }
        .padding()
        .frame(width: 500)
    }

    private var hookContent: String {
        """
        # Boop Shell Integration
        # Wraps claude and codex commands to monitor output

        # Only active when Boop app is running (socket exists)
        # Provides transparent passthrough - commands work normally

        \(shellService.detectedShell.sourceLine)

        # The hook:
        # 1. Generates a unique session ID
        # 2. Detects project name from git or directory
        # 3. Wraps the command in a PTY for output monitoring
        # 4. Sends state changes to Boop via Unix socket
        """
    }

    private func installHooks() {
        isInstalling = true
        installError = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try shellService.installHooks()
                DispatchQueue.main.async {
                    isInstalling = false
                }
            } catch {
                DispatchQueue.main.async {
                    installError = error.localizedDescription
                    isInstalling = false
                }
            }
        }
    }
}

#Preview {
    ShellIntegrationView(onContinue: {}, onBack: {})
        .frame(width: 500, height: 550)
}
