import SwiftUI
struct ConversationPhase: View {
    @Environment(WizardState.self) private var wizardState; @Environment(AIConfigState.self) private var aiConfig
    var simpleMode: Bool = false
    @State private var inputText = ""; @State private var isLoading = false; @State private var error: String?; @State private var conversationComplete = false; @State private var hasInitialized = false
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if wizardState.conversationMessages.isEmpty && !isLoading { Text("Starting conversation...").font(.callout).foregroundStyle(ShellmateColors.textMuted).frame(maxWidth: .infinity).padding(.top, 60) }
                        ForEach(wizardState.conversationMessages) { m in MessageBubble(message: ChatMessage(id: m.id, role: m.role, content: m.role == .assistant ? stripSpec(m.content) : m.content)) }
                        if isLoading { HStack(spacing: 8) { BouncingDots(); Text("Thinking...").font(.caption).foregroundStyle(ShellmateColors.textMuted) }.padding(.horizontal, 12).padding(.vertical, 8).background(ShellmateColors.navy800).clipShape(RoundedRectangle(cornerRadius: 12)) }
                        if let error { Text(error).font(.caption).foregroundStyle(ShellmateColors.error).padding(12).background(ShellmateColors.error.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10)) }
                        if conversationComplete && !isLoading {
                            VStack(spacing: 12) { Text("All set! Ready to review.").font(.callout.weight(.medium)).foregroundStyle(ShellmateColors.success); BigButton("Review & generate", icon: "arrow.right", action: { wizardState.nextPhase() }).frame(maxWidth: 280) }
                            .padding(16).background(ShellmateColors.success.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding()
                }.onChange(of: wizardState.conversationMessages.count) { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
                .onChange(of: isLoading) { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
            Divider().background(ShellmateColors.navy700)
            inputSection
        }.task { if !hasInitialized && aiConfig.isConfigured && wizardState.conversationMessages.isEmpty { hasInitialized = true; await sendToAI("Hi! I'd like to set up my Mac helper.", opening: true) } }
    }
    private var inputSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                TextField("Type your reply...", text: $inputText, axis: .vertical).textFieldStyle(.plain).font(.body).foregroundStyle(ShellmateColors.textPrimary).padding(12).background(ShellmateColors.navy800).clipShape(RoundedRectangle(cornerRadius: 12)).lineLimit(1...4).disabled(isLoading).onSubmit { handleSend() }
                Button(action: handleSend) { Text("Send").font(.callout.bold()).foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 10).background(ShellmateColors.shell600).clipShape(RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain).disabled(isLoading || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).opacity(isLoading || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
            }.padding(.horizontal, 16).padding(.vertical, 12)
            HStack { Text("Press Return to send").font(.caption2).foregroundStyle(ShellmateColors.textMuted); Spacer()
                if !conversationComplete && wizardState.conversationMessages.count >= 10 { Button("Skip to review") { wizardState.nextPhase() }.font(.caption2).foregroundStyle(ShellmateColors.textMuted).buttonStyle(.plain) }
            }.padding(.horizontal, 20).padding(.bottom, 8)
        }.background(ShellmateColors.navy900)
    }
    private func handleSend() { let t = inputText.trimmingCharacters(in: .whitespacesAndNewlines); guard !t.isEmpty, !isLoading else { return }; inputText = ""; Task { await sendToAI(t, opening: false) } }
    private func sendToAI(_ text: String, opening: Bool) async {
        guard let key = aiConfig.resolveApiKey() else { error = "No API key."; return }
        if !opening { wizardState.conversationMessages.append(ChatMessage(role: .user, content: text)) }
        isLoading = true; error = nil
        let router = AIRouter(); let sp = simpleMode ? "You are setting up Shellmate for a non-technical user. SHORT conversation (3-4 exchanges). Simple language. Ask: name, Mac usage, apps, one wish. Then output <shellmate-spec complete=\"true\"> with flat JSON." : "You are a friendly Mac setup assistant for Shellmate. Warm, concise. One question at a time. Learn: name, Mac usage, apps, automation wishes, never rules, personality. Output <shellmate-spec> blocks with JSON. Use complete=\"true\" after confirmation."
        nonisolated(unsafe) let msgs: [[String: Any]] = opening ? [["role":"user","content":"Greet warmly and ask their name and Mac usage."]] : wizardState.conversationMessages.map { ["role":$0.role.rawValue,"content":$0.content] }
        do {
            let r = try await router.call(messages: msgs, system: sp, provider: aiConfig.provider, model: aiConfig.model, apiKey: key, maxTokens: 4096)
            wizardState.conversationMessages.append(ChatMessage(role: .assistant, content: r.text))
            for b in parseSpec(r.text) { mergeSpec(b.0); if b.1 { conversationComplete = true } }
        } catch { self.error = error.localizedDescription }
        isLoading = false
    }
    private func parseSpec(_ c: String) -> [([String:Any], Bool)] {
        var res: [([String:Any], Bool)] = []; let p = #"<shellmate-spec(\s+complete="true")?>([\s\S]*?)</shellmate-spec>"#
        guard let re = try? NSRegularExpression(pattern: p) else { return res }; let ns = c as NSString
        for m in re.matches(in: c, range: NSRange(location: 0, length: ns.length)) {
            let complete = m.range(at: 1).location != NSNotFound; let j = ns.substring(with: m.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            if let d = j.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) as? [String:Any] { res.append((o, complete)) }
        }; return res
    }
    private func stripSpec(_ c: String) -> String {
        let p = #"<shellmate-spec[\s\S]*?</shellmate-spec>"#; guard let re = try? NSRegularExpression(pattern: p) else { return c }
        return re.stringByReplacingMatches(in: c, range: NSRange(location: 0, length: (c as NSString).length), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private func mergeSpec(_ j: [String:Any]) {
        if let v = j["name"] as? String { wizardState.agentSpec.name = v }; if let v = j["personality"] as? String { wizardState.agentSpec.personality = v }
        if let v = j["mission"] as? String { wizardState.agentSpec.mission = v }; if let v = j["mac_apps"] as? [String] { wizardState.agentSpec.macApps = v }
        if let v = j["use_cases"] as? [String] { wizardState.agentSpec.useCases = v }; if let v = j["failure"] as? String { wizardState.agentSpec.failure = v }
        if let v = j["escalation"] as? String { wizardState.agentSpec.escalation = v }; if let v = j["never"] as? [String] { wizardState.agentSpec.never = v }
    }
}
