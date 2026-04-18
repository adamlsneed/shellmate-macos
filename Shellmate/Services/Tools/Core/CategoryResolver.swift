import Foundation

// MARK: - CategoryResolver

/// Determines which ``ToolCategory`` values are relevant for a user message.
///
/// This is a token-budget optimisation: by only sending schemas for likely
/// categories we reduce prompt size without meaningful accuracy loss.
/// False positives are acceptable; false negatives are not — so when no
/// keywords match we fall back to sending **all** enabled categories.
struct CategoryResolver: Sendable {

    // Categories included in every request (when enabled).
    private static let alwaysIncluded: Set<ToolCategory> = [.shell, .files]

    // Keyword map used for lightweight intent detection.
    private static let keywordMap: [ToolCategory: [String]] = [
        .calendar:    ["calendar", "event", "schedule", "meeting", "appointment", "busy", "free time"],
        .reminders:   ["remind", "reminder", "todo", "to-do", "task", "due"],
        .contacts:    ["contact", "phone number", "email address", "address book"],
        .notes:       ["note", "notes app", "write a note", "jot down"],
        .email:       ["email", "mail", "inbox", "send a message", "unread"],
        .clipboard:   ["clipboard", "paste", "copy"],
        .system:      ["system info", "cpu", "memory", "ram", "disk space", "storage", "battery", "uptime"],
        .display:     ["brightness", "dark mode", "night shift", "resolution", "display"],
        .audio:       ["volume", "mute", "audio", "sound", "music", "playing", "song", "speaker"],
        .apps:        ["install", "uninstall", "update app", "homebrew", "brew", "app store"],
        .web:         ["search the web", "look up", "fetch page", "download"],
        .developer:   ["git", "docker", "ssh", "port", "commit", "branch", "pull", "push"],
        .network:     ["wifi", "network", "bluetooth", "ping", "dns", "vpn", "internet"],
        .automation:  ["shortcut", "cron", "automate", "launch agent"],
        // ScreenshotCaptureTool lives in MediaProvider (.media), so screenshot keywords
        // route to .media. The legacy .screenshot enum case is unused for routing.
        .media:       ["image", "photo", "pdf", "resize", "convert image", "ocr",
                       "screenshot", "screen capture", "screen shot"],
        .tts:         ["speak", "read aloud", "text to speech", "voice"],
    ]

    /// Resolve which tool categories are relevant for the given message.
    ///
    /// - Parameters:
    ///   - message: The user's chat message.
    ///   - enabledCategories: Categories the user has enabled in settings.
    /// - Returns: The subset of enabled categories to include in the API call.
    func resolve(message: String, enabledCategories: Set<ToolCategory>) -> Set<ToolCategory> {
        let lowered = message.lowercased()

        // Always-on categories (intersected with what's enabled).
        var matched = Self.alwaysIncluded.intersection(enabledCategories)

        // Check keyword map for additional categories.
        var foundSpecific = false
        for (category, keywords) in Self.keywordMap {
            guard enabledCategories.contains(category) else { continue }
            if keywords.contains(where: { lowered.contains($0) }) {
                matched.insert(category)
                foundSpecific = true
            }
        }

        // If nothing beyond always-included matched, fall back to everything.
        if !foundSpecific {
            return enabledCategories
        }

        return matched
    }
}
