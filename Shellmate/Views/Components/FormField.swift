import SwiftUI
struct FormField: View {
    let label: String; @Binding var text: String; var placeholder: String = ""; var isSecure: Bool = false; var hint: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(ShellmateColors.textMuted)
            Group { if isSecure { SecureField(placeholder, text: $text) } else { TextField(placeholder, text: $text) } }
                .textFieldStyle(.plain).foregroundStyle(ShellmateColors.textPrimary).padding(10)
                .background(ShellmateColors.navy950).clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ShellmateColors.navy700, lineWidth: 1))
            if let hint { Text(hint).font(.caption2).foregroundStyle(ShellmateColors.textMuted) }
        }
    }
}
