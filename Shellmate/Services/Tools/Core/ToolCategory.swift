// MARK: - ToolCategory

/// Categorises agent tools by domain for capability grouping and settings UI.
enum ToolCategory: String, CaseIterable, Sendable, Codable {
    case shell
    case system
    case files
    case clipboard
    case display
    case audio
    case screenshot
    case calendar
    case reminders
    case contacts
    case notes
    case email
    case apps
    case web
    case developer
    case network
    case automation
    case media
    case tts
    case windows

    var displayName: String {
        switch self {
        case .shell:        "Shell"
        case .system:       "System"
        case .files:        "Files"
        case .clipboard:    "Clipboard"
        case .display:      "Display"
        case .audio:        "Audio"
        case .screenshot:   "Screenshot"
        case .calendar:     "Calendar"
        case .reminders:    "Reminders"
        case .contacts:     "Contacts"
        case .notes:        "Notes"
        case .email:        "Email"
        case .apps:         "Apps"
        case .web:          "Web"
        case .developer:    "Developer"
        case .network:      "Network"
        case .automation:   "Automation"
        case .media:        "Media"
        case .tts:          "Text to Speech"
        case .windows:      "Window Management"
        }
    }
}

// MARK: - SystemPermission

/// macOS privacy permissions that tools may require.
enum SystemPermission: String, CaseIterable, Sendable {
    case calendars
    case reminders
    case contacts
    case location
    case microphone
    case screenCapture
    case accessibility
    case appleEvents
    case bluetooth

    var displayName: String {
        switch self {
        case .calendars:     "Calendars"
        case .reminders:     "Reminders"
        case .contacts:      "Contacts"
        case .location:      "Location"
        case .microphone:    "Microphone"
        case .screenCapture: "Screen Recording"
        case .accessibility: "Accessibility"
        case .appleEvents:   "Automation"
        case .bluetooth:     "Bluetooth"
        }
    }

    /// Friendly message shown to the user before macOS triggers its permission dialog.
    var prePromptMessage: String {
        switch self {
        case .calendars:
            "To check your schedule, I need to ask macOS for permission to see your calendar. You'll see a popup from macOS in a moment — go ahead and click Allow. This is normal and safe."
        case .reminders:
            "To work with your reminders, I need to ask macOS for permission to access them. You'll see a popup from macOS in a moment — go ahead and click Allow. This is normal and safe."
        case .contacts:
            "To look up contact information, I need to ask macOS for permission to see your contacts. You'll see a popup from macOS in a moment — go ahead and click Allow. This is normal and safe."
        case .location:
            "To find your location, I need to ask macOS for permission to check where you are. You'll see a popup from macOS in a moment — go ahead and click Allow. This is normal and safe."
        case .microphone:
            "To listen to audio, I need to ask macOS for permission to use your microphone. You'll see a popup from macOS in a moment — go ahead and click Allow. This is normal and safe."
        case .screenCapture:
            "To see what's on your screen, I need to ask macOS for permission to record your display. You'll see a popup from macOS in a moment — go ahead and click Allow. This is normal and safe."
        case .accessibility:
            "To control parts of your Mac (like clicking buttons or typing), I need accessibility permission. You'll see a popup from macOS in a moment — go ahead and click Allow. This is normal and safe."
        case .appleEvents:
            "To work with other apps on your Mac, I need permission to send them commands. You'll see a popup from macOS in a moment — go ahead and click Allow. This is normal and safe."
        case .bluetooth:
            "To connect to nearby devices, I need to ask macOS for permission to use Bluetooth. You'll see a popup from macOS in a moment — go ahead and click Allow. This is normal and safe."
        }
    }

    /// Message shown when the user has previously denied the permission.
    var deniedMessage: String {
        switch self {
        case .calendars:
            "It looks like calendar access was turned off earlier. To fix this, open System Settings, go to Privacy & Security, then Calendars, and switch Shellmate on."
        case .reminders:
            "It looks like reminders access was turned off earlier. To fix this, open System Settings, go to Privacy & Security, then Reminders, and switch Shellmate on."
        case .contacts:
            "It looks like contacts access was turned off earlier. To fix this, open System Settings, go to Privacy & Security, then Contacts, and switch Shellmate on."
        case .location:
            "It looks like location access was turned off earlier. To fix this, open System Settings, go to Privacy & Security, then Location Services, and switch Shellmate on."
        case .microphone:
            "It looks like microphone access was turned off earlier. To fix this, open System Settings, go to Privacy & Security, then Microphone, and switch Shellmate on."
        case .screenCapture:
            "It looks like screen recording was turned off earlier. To fix this, open System Settings, go to Privacy & Security, then Screen Recording, and switch Shellmate on."
        case .accessibility:
            "It looks like accessibility access was turned off earlier. To fix this, open System Settings, go to Privacy & Security, then Accessibility, and switch Shellmate on."
        case .appleEvents:
            "It looks like automation access was turned off earlier. To fix this, open System Settings, go to Privacy & Security, then Automation, and switch Shellmate on."
        case .bluetooth:
            "It looks like Bluetooth access was turned off earlier. To fix this, open System Settings, go to Privacy & Security, then Bluetooth, and switch Shellmate on."
        }
    }

    /// Deep link to the relevant System Settings privacy pane.
    var settingsPaneURL: String {
        switch self {
        case .calendars:     "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        case .reminders:     "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
        case .contacts:      "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts"
        case .location:      "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
        case .microphone:    "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .screenCapture: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .accessibility: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .appleEvents:   "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        case .bluetooth:     "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth"
        }
    }
}
