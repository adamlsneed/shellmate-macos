import SwiftUI

/// Large, accessible button used throughout the app.
struct BigButton: View {
    let label: String
    let icon: String?
    let style: BigButtonStyle
    let action: () -> Void

    enum BigButtonStyle {
        case primary, secondary

        var background: Color {
            switch self {
            case .primary: ShellmateColors.accent
            case .secondary: ShellmateColors.navy700
            }
        }

        var foreground: Color {
            switch self {
            case .primary: ShellmateColors.navy950
            case .secondary: ShellmateColors.textPrimary
            }
        }
    }

    init(_ label: String, icon: String? = nil, style: BigButtonStyle = .primary, action: @escaping () -> Void) {
        self.label = label
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(label)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(style.background)
            .foregroundStyle(style.foreground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
