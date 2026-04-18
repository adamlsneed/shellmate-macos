import SwiftUI

// MARK: - ConfirmationCardView

/// Inline card shown in the chat when a tool requires user confirmation before execution.
/// Destructive actions get an orange warning treatment; all tiers show Approve/Deny buttons.
struct ConfirmationCardView: View {
    let request: ConfirmationRequest
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if request.tier == .destructive {
                Label("Warning", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.headline)
            }
            Text(request.description)
                .font(.body)
            if request.tier == .destructive {
                Text("This cannot be easily undone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button("Approve") {
                    request.continuation.resume(returning: true)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                Button("Deny") {
                    request.continuation.resume(returning: false)
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    request.tier == .destructive ? Color.orange.opacity(0.5) : Color.clear,
                    lineWidth: 1
                )
        )
        // If the card disappears without an explicit Approve/Deny click (window close,
        // chat reset, view reflow), treat it as denied so the awaiting tool resumes.
        // OneShotContinuation makes resume() idempotent — safe even after a button click.
        .onDisappear {
            request.continuation.resume(returning: false)
        }
    }
}
