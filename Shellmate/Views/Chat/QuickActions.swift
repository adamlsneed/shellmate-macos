import SwiftUI

/// Grid of suggestion buttons shown when chat is empty.
struct QuickActions: View {
    let onSelect: (String) -> Void

    private let suggestions = [
        QuickAction(icon: "folder.fill", label: "Organize my Desktop", prompt: "Help me organize the files on my Desktop into folders"),
        QuickAction(icon: "doc.text.magnifyingglass", label: "Find a file", prompt: "Help me find a file on my Mac"),
        QuickAction(icon: "globe", label: "Search the web", prompt: "Search the web for the latest news"),
        QuickAction(icon: "terminal.fill", label: "System info", prompt: "Show me information about my Mac"),
        QuickAction(icon: "photo.fill", label: "Manage photos", prompt: "Help me find and organize photos on my Mac"),
        QuickAction(icon: "calendar", label: "What day is it?", prompt: "What's today's date and what events do I have coming up?"),
    ]

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ], spacing: 12) {
            ForEach(suggestions) { suggestion in
                Button(action: { onSelect(suggestion.prompt) }) {
                    HStack(spacing: 10) {
                        Image(systemName: suggestion.icon)
                            .foregroundStyle(ShellmateColors.shell400)
                        Text(suggestion.label)
                            .foregroundStyle(ShellmateColors.textPrimary)
                        Spacer()
                    }
                    .padding(12)
                    .background(ShellmateColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 40)
    }
}

struct QuickAction: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let prompt: String
}
