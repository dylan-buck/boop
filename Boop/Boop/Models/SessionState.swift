import Foundation
import SwiftUI

enum SessionState: String, Codable, CaseIterable {
    case working = "WORKING"
    case awaitingApproval = "AWAITING_APPROVAL"
    case completed = "COMPLETED"
    case error = "ERROR"

    var displayName: String {
        switch self {
        case .working:
            return "Working"
        case .awaitingApproval:
            return "Waiting for approval"
        case .completed:
            return "Completed"
        case .error:
            return "Error"
        }
    }

    var icon: String {
        switch self {
        case .working:
            return "circle.fill"
        case .awaitingApproval:
            return "circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .working:
            return .green
        case .awaitingApproval:
            return .orange
        case .completed:
            return .green
        case .error:
            return .red
        }
    }

    var needsAttention: Bool {
        switch self {
        case .awaitingApproval, .completed, .error:
            return true
        case .working:
            return false
        }
    }
}
