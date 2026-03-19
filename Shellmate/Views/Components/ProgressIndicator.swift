import SwiftUI

/// 5-phase wizard progress bar with labels.
struct ProgressIndicator: View {
    let currentPhase: Int
    let totalPhases: Int
    let labels: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<totalPhases, id: \.self) { index in
                HStack(spacing: 4) {
                    Circle()
                        .fill(index <= currentPhase ? ShellmateColors.accent : ShellmateColors.navy700)
                        .frame(width: 10, height: 10)

                    if index < labels.count {
                        Text(labels[index])
                            .font(.caption2)
                            .foregroundStyle(
                                index <= currentPhase
                                    ? ShellmateColors.textPrimary
                                    : ShellmateColors.textMuted
                            )
                    }
                }

                if index < totalPhases - 1 {
                    Rectangle()
                        .fill(index < currentPhase ? ShellmateColors.accent : ShellmateColors.navy700)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
