import Foundation
import Observation

/// Long-lived owner of every tool-system service.
///
/// Was previously rebuilt per `ChatView.sendMessage`, which silently reset
/// `ShellService.history`, `ConfirmationService.autoApproveCategories`,
/// `PermissionManager.cache`, and forced re-instantiation of EventKit/Contacts
/// stores on every chat round. Lifting these into a single instance owned by
/// `ShellmateApp` lets state survive across messages and keeps `which("brew")`
/// caches warm.
///
/// `ChatView` calls `attach(chatState:)` once when it mounts and
/// `reconcile(capConfig:)` before each send to bring the registry in line with
/// the user's current settings (a diff, not a full rebuild).
@Observable
@MainActor
final class ToolingState {
    let shellService: ShellService
    let appleScriptService: AppleScriptService
    let registry: ToolRegistry
    let confirmationService: ConfirmationService
    let permissionManager: PermissionManager
    let executor: ToolExecutor
    let loop: ToolUseLoop

    private let uiHandler: ConfirmationUIHandler
    private var registeredCategories: Set<ToolCategory> = []
    private var registeredAutoApprove: Set<ToolCategory> = []

    init() {
        let shell = ShellService()
        self.shellService = shell
        self.appleScriptService = AppleScriptService(shellService: shell)
        self.registry = ToolRegistry()
        self.uiHandler = ConfirmationUIHandler()
        self.confirmationService = ConfirmationService(uiHandler: uiHandler)
        self.permissionManager = PermissionManager()
        self.executor = ToolExecutor(
            registry: registry,
            confirmationService: confirmationService,
            permissionManager: permissionManager
        )
        self.loop = ToolUseLoop(executor: executor)
    }

    /// Bind the UI handler to this view's chat state so confirmation cards land
    /// on the right `ChatState`. Call once per view mount.
    func attach(chatState: ChatState) {
        uiHandler.chatState = chatState
    }

    /// Diff registered providers + auto-approve settings against the current
    /// config. Cheaper than tearing everything down: only newly-enabled
    /// providers are constructed; only newly-disabled ones are removed.
    func reconcile(capConfig: CapabilitiesConfig) async {
        let desiredCats = Set(capConfig.enabledCategories.compactMap { ToolCategory(rawValue: $0) })

        let toRemove = registeredCategories.subtracting(desiredCats)
        for cat in toRemove {
            await registry.unregister(cat)
        }

        let toAdd = desiredCats.subtracting(registeredCategories)
        for cat in toAdd {
            if let provider = makeProvider(for: cat) {
                await registry.register(provider)
            }
        }
        registeredCategories = desiredCats

        let desiredAuto = Set(capConfig.autoApproveCategories.compactMap { ToolCategory(rawValue: $0) })
        for cat in registeredAutoApprove.subtracting(desiredAuto) {
            await confirmationService.setAutoApprove(for: cat, enabled: false)
        }
        for cat in desiredAuto.subtracting(registeredAutoApprove) {
            await confirmationService.setAutoApprove(for: cat, enabled: true)
        }
        registeredAutoApprove = desiredAuto
    }

    private func makeProvider(for cat: ToolCategory) -> ToolProvider? {
        switch cat {
        case .shell:      ShellProvider(shellService: shellService)
        case .files:      FilesProvider(shellService: shellService)
        case .web:        WebProvider(shellService: shellService)
        case .system:     SystemProvider(shellService: shellService)
        case .clipboard:  ClipboardProvider()
        case .display:    DisplayProvider(shellService: shellService)
        case .audio:      AudioProvider(shellService: shellService)
        case .calendar:   CalendarProvider()
        case .reminders:  RemindersProvider()
        case .contacts:   ContactsProvider()
        case .apps:       AppsProvider(shellService: shellService)
        case .developer:  DeveloperProvider(shellService: shellService)
        case .network:    NetworkProvider(shellService: shellService)
        case .notes:      NotesProvider(appleScriptService: appleScriptService)
        case .email:      EmailProvider(shellService: shellService, appleScriptService: appleScriptService)
        case .automation: AutomationProvider(shellService: shellService)
        case .media:      MediaProvider(shellService: shellService, appleScriptService: appleScriptService)
        case .tts:        TTSProvider(shellService: shellService)
        case .windows:    WindowProvider()
        case .screenshot: nil
        }
    }
}
