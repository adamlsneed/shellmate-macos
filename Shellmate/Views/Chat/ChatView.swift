import SwiftUI

/// Full-screen chat interface wired to ToolUseLoop for actual AI calls.
struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(AIConfigState.self) private var aiConfig
    @State private var chatState = ChatState()
    @State private var sendTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) { Image(systemName: "terminal.fill").font(.title2).foregroundStyle(ShellmateColors.accent); Text("Shellmate").font(.title3.bold()).foregroundStyle(ShellmateColors.accent) }
                Spacer()
            }.padding(.horizontal, 20).padding(.vertical, 12).background(ShellmateColors.navy900)
            Divider().background(ShellmateColors.navy700)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if chatState.messages.isEmpty && !chatState.isStreaming { emptyState }
                        ForEach(chatState.messages) { message in MessageBubble(message: message) }
                        ForEach(chatState.currentToolCalls) { s in streamingToolCall(s) }
                        if let confirmation = chatState.pendingConfirmation {
                            ConfirmationCardView(request: confirmation) {
                                chatState.pendingConfirmation = nil
                            }
                        }
                        if chatState.isStreaming && !chatState.currentStreamingText.isEmpty {
                            MessageBubble(message: ChatMessage(role: .assistant, content: chatState.currentStreamingText))
                        }
                        if chatState.isStreaming && chatState.currentStreamingText.isEmpty && chatState.currentToolCalls.isEmpty {
                            HStack(spacing: 8) { BouncingDots(); Text("Thinking...").font(.caption).foregroundStyle(ShellmateColors.textMuted) }
                                .padding(.horizontal, 12).padding(.vertical, 8).background(ShellmateColors.navy800).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        if let error = chatState.error {
                            Text(error).font(.caption).foregroundStyle(ShellmateColors.error).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(ShellmateColors.error.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Color.clear.frame(height: 1).id("chatBottom")
                    }.padding()
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: chatState.messages.count) { withAnimation { proxy.scrollTo("chatBottom", anchor: .bottom) } }
                .onChange(of: chatState.currentStreamingText) { proxy.scrollTo("chatBottom", anchor: .bottom) }
                .onChange(of: chatState.currentToolCalls.count) { proxy.scrollTo("chatBottom", anchor: .bottom) }
            }
            Divider().background(ShellmateColors.navy700)
            inputBar
        }.background(ShellmateColors.background)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            Image(systemName: "terminal.fill").font(.system(size: 48)).foregroundStyle(ShellmateColors.shell400.opacity(0.5))
            Text("How can I help?").font(.title2.bold()).foregroundStyle(ShellmateColors.textPrimary)
            Text("Ask me anything about your Mac, or try one of these:").font(.callout).foregroundStyle(ShellmateColors.textSecondary)
            QuickActions { prompt in sendMessage(prompt) }
        }.frame(maxWidth: .infinity)
    }

    private func streamingToolCall(_ status: ToolCallStatus) -> some View {
        HStack(spacing: 8) {
            if !status.isComplete { LoadingSpinner() } else { Image(systemName: status.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill").foregroundStyle(status.isError ? ShellmateColors.error : ShellmateColors.success) }
            VStack(alignment: .leading, spacing: 2) {
                Label(status.toolName.isEmpty ? "Running tool..." : FriendlyToolStatus.describe(ToolCall(id: status.id, name: status.toolName, input: [:])), systemImage: FriendlyToolStatus.icon(for: status.toolName)).font(.caption).foregroundStyle(ShellmateColors.shell400)
                if let result = status.result, status.isComplete { Text(String(result.prefix(200))).font(.system(.caption2, design: .monospaced)).foregroundStyle(status.isError ? ShellmateColors.error : ShellmateColors.textMuted).lineLimit(3) }
            }
        }.padding(10).background(ShellmateColors.navy850).clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Message your assistant...", text: $chatState.inputText, axis: .vertical)
                .textFieldStyle(.plain).font(.body).foregroundStyle(ShellmateColors.textPrimary)
                .padding(12).background(ShellmateColors.surface).clipShape(RoundedRectangle(cornerRadius: 12)).lineLimit(1...5)
                .onSubmit { let t = chatState.inputText.trimmingCharacters(in: .whitespacesAndNewlines); if !t.isEmpty { sendMessage(t) } }
            Button(action: {
                if chatState.isStreaming { cancelStreaming() } else { let t = chatState.inputText.trimmingCharacters(in: .whitespacesAndNewlines); if !t.isEmpty { sendMessage(t) } }
            }) {
                Image(systemName: chatState.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill").font(.title2).foregroundStyle(ShellmateColors.accent)
            }.buttonStyle(.plain).disabled(chatState.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatState.isStreaming)
        }.padding(16).background(ShellmateColors.navy900)
    }

    private func sendMessage(_ text: String) {
        chatState.addUserMessage(text); chatState.isStreaming = true; chatState.error = nil
        guard let apiKey = aiConfig.resolveApiKey() else { chatState.error = "No API key configured."; chatState.isStreaming = false; return }
        let ws = WorkspaceService(); let sp: String
        if ws.isSetUp, let s = try? String(contentsOf: ws.workspacePath.appendingPathComponent("SYSTEM.md"), encoding: .utf8) { sp = s } else { sp = "You are Shellmate, a helpful Mac assistant." }
        let cs = ConfigService()
        let capConfig = (try? cs.readConfig())?.capabilities ?? CapabilitiesConfig()
        var deny: [ToolDenyCategory] = []
        for cat in ToolDenyCategory.allCases { if capConfig.tools.deny.contains(cat.rawValue) { deny.append(cat) } }
        let enabledSet = Set(capConfig.enabledCategories)
        let msgs: [SendableDict] = chatState.messages.map { SendableDict(["role": $0.role.rawValue, "content": $0.content]) }
        let shellService = ShellService()
        let appleScriptService = AppleScriptService(shellService: shellService)
        let registry = ToolRegistry()
        let uiHandler = ConfirmationUIHandler()
        uiHandler.chatState = chatState
        let confirmation = ConfirmationService(uiHandler: uiHandler)
        let permissions = PermissionManager()
        let executor = ToolExecutor(registry: registry, confirmationService: confirmation, permissionManager: permissions)
        let loop = ToolUseLoop(executor: executor)
        sendTask = Task {
            // Apply auto-approve settings from config
            for catRaw in capConfig.autoApproveCategories {
                if let cat = ToolCategory(rawValue: catRaw) {
                    await confirmation.setAutoApprove(for: cat, enabled: true)
                }
            }

            // Register only enabled providers
            let allProviders: [ToolProvider] = [
                ShellProvider(shellService: shellService),
                FilesProvider(shellService: shellService),
                WebProvider(shellService: shellService),
                SystemProvider(shellService: shellService),
                ClipboardProvider(),
                DisplayProvider(shellService: shellService),
                AudioProvider(shellService: shellService),
                CalendarProvider(),
                RemindersProvider(),
                ContactsProvider(),
                AppsProvider(shellService: shellService),
                DeveloperProvider(shellService: shellService),
                NetworkProvider(shellService: shellService),
                NotesProvider(appleScriptService: appleScriptService),
                EmailProvider(shellService: shellService, appleScriptService: appleScriptService),
                AutomationProvider(shellService: shellService),
                MediaProvider(shellService: shellService, appleScriptService: appleScriptService),
                TTSProvider(shellService: shellService),
                WindowProvider(),
            ]
            for provider in allProviders where enabledSet.contains(provider.category.rawValue) {
                await registry.register(provider)
            }
            let enabledCats = Set(capConfig.enabledCategories.compactMap { ToolCategory(rawValue: $0) })
            await loop.run(messages: msgs, system: sp, provider: aiConfig.provider, model: aiConfig.model, apiKey: apiKey, enabledCategories: enabledCats, denyCategories: deny, onEvent: { @Sendable ev in Task { @MainActor in handleEvent(ev) } })
        }
    }

    @MainActor private func handleEvent(_ ev: ToolUseLoop.LoopEvent) {
        switch ev {
        case .textDelta(let t): chatState.currentStreamingText += t
        case .toolCallStarted(let id, let name, let input): chatState.currentToolCalls.append(ToolCallStatus(id: id, toolName: name, input: input))
        case .toolCallCompleted(let id, let r, let e): if let i = chatState.currentToolCalls.firstIndex(where: { $0.id == id }) { chatState.currentToolCalls[i].result = r; chatState.currentToolCalls[i].isComplete = true; chatState.currentToolCalls[i].isError = e }
        case .roundComplete: break
        case .finished(let ft):
            var tc: [ToolCall] = []; var tr: [ToolResult] = []
            for s in chatState.currentToolCalls { tc.append(ToolCall(id: s.id, name: s.toolName, input: [:])); if let r = s.result { tr.append(ToolResult(id: s.id, content: r, isError: s.isError)) } }
            if !ft.isEmpty || !tc.isEmpty { chatState.messages.append(ChatMessage(role: .assistant, content: ft, toolCalls: tc, toolResults: tr)) }
            chatState.clearStreaming()
        case .error(let m): chatState.error = m; if !chatState.currentStreamingText.isEmpty { chatState.addAssistantMessage(chatState.currentStreamingText) }; chatState.clearStreaming()
        }
    }

    private func cancelStreaming() {
        sendTask?.cancel(); if !chatState.currentStreamingText.isEmpty { chatState.addAssistantMessage(chatState.currentStreamingText) }; chatState.clearStreaming()
    }
}
