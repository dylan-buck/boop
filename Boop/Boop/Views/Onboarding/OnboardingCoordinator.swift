import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case phoneSetup
    case shellIntegration
    case completion
}

struct OnboardingCoordinator: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var configManager = ConfigurationManager.shared

    @State private var currentStep: OnboardingStep = .welcome

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressIndicator
                .padding(.top, 16)

            // Content
            Group {
                switch currentStep {
                case .welcome:
                    WelcomeView(onContinue: nextStep)

                case .phoneSetup:
                    PhoneSetupView(onContinue: nextStep, onBack: previousStep)

                case .shellIntegration:
                    ShellIntegrationView(onContinue: nextStep, onBack: previousStep)

                case .completion:
                    CompletionView(onFinish: finishOnboarding)
                }
            }
        }
        .frame(width: 500, height: 600)
    }

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func nextStep() {
        withAnimation {
            if let nextIndex = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                currentStep = nextIndex
            }
        }
    }

    private func previousStep() {
        withAnimation {
            if let prevIndex = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                currentStep = prevIndex
            }
        }
    }

    private func finishOnboarding() {
        configManager.settings.onboardingComplete = true
        dismiss()
    }
}

#Preview {
    OnboardingCoordinator()
}
