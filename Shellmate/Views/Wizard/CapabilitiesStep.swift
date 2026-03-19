import SwiftUI
struct CapabilitiesStep: View {
    @Environment(WizardState.self) private var wizardState
    @State private var memoryMode = "core"; @State private var webSearch = false; @State private var braveKey = ""; @State private var webFetch = false
    @State private var allowExec = true; @State private var allowWrite = true; @State private var allowBrowser = true
    @State private var saving = false; @State private var saved = false; @State private var error: String?
    private let cs = ConfigService()
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            Text("BASICS").font(.caption2.weight(.semibold)).foregroundStyle(ShellmateColors.textMuted).tracking(1)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) { Image(systemName: "brain").foregroundStyle(ShellmateColors.shell400); Text("Memory").font(.callout.bold()).foregroundStyle(ShellmateColors.textPrimary) }
                HStack(spacing: 8) { memOpt("none", "None", "Manual only"); memOpt("core", "Core", "Recommended", "default") }
            }.padding(16).background(ShellmateColors.navy800.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
            capCard("Web Search", "magnifyingglass", "Brave Search API.", $webSearch) { FormField(label: "Brave API Key", text: $braveKey, placeholder: "BSA...", isSecure: true) }
            capCard("Web Browsing", "globe", "Fetch web pages.", $webFetch) { EmptyView() }
            Divider().background(ShellmateColors.navy700)
            Text("PERMISSIONS").font(.caption2.weight(.semibold)).foregroundStyle(ShellmateColors.textMuted).tracking(1)
            safeRow("Run commands", "Shell, scripts", $allowExec); safeRow("Modify files", "Create, edit, delete", $allowWrite); safeRow("Browse web", "Open pages", $allowBrowser)
            if let error { Text(error).font(.caption).foregroundStyle(ShellmateColors.error) }
            HStack(spacing: 12) { if !saved { BigButton(saving ? "Saving..." : "Save", icon: "arrow.right") { Task { await save() } }.disabled(saving); Button("Skip") { wizardState.nextPhase() }.font(.callout).foregroundStyle(ShellmateColors.textMuted).buttonStyle(.plain) } else { HStack(spacing: 8) { Image(systemName: "checkmark.circle.fill").foregroundStyle(ShellmateColors.success); Text("Saved").foregroundStyle(ShellmateColors.success) }; BigButton("Finish", icon: "arrow.right") { wizardState.nextPhase() } } }
        }.padding(24) }.task { guard let c = try? cs.readConfig() else { return }; webSearch = c.capabilities.webSearch; webFetch = c.capabilities.webFetch; let d = c.capabilities.tools.deny; allowExec = !d.contains("exec"); allowWrite = !d.contains("write"); allowBrowser = !d.contains("browser") }
    }
    private func memOpt(_ id: String, _ l: String, _ d: String, _ badge: String? = nil) -> some View {
        Button(action: { memoryMode = id }) { VStack(alignment: .leading, spacing: 4) { HStack { Text(l).font(.caption.bold()); if let b = badge { Text(b).font(.system(size: 9)).padding(.horizontal, 4).padding(.vertical, 2).background(ShellmateColors.shell600.opacity(0.3)).foregroundStyle(ShellmateColors.shell400).clipShape(RoundedRectangle(cornerRadius: 4)) } }; Text(d).font(.caption2).foregroundStyle(ShellmateColors.textMuted) }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(memoryMode == id ? ShellmateColors.shell600.opacity(0.15) : ShellmateColors.navy950.opacity(0.5)).foregroundStyle(memoryMode == id ? ShellmateColors.textPrimary : ShellmateColors.textMuted).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(memoryMode == id ? ShellmateColors.shell500 : ShellmateColors.navy700, lineWidth: 1)) }.buttonStyle(.plain)
    }
    private func capCard<C: View>(_ t: String, _ i: String, _ d: String, _ on: Binding<Bool>, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) { HStack { HStack(spacing: 8) { Image(systemName: i).foregroundStyle(ShellmateColors.shell400); Text(t).font(.callout.bold()).foregroundStyle(ShellmateColors.textPrimary) }; Spacer(); Toggle("", isOn: on).toggleStyle(.switch).tint(ShellmateColors.shell600) }; Text(d).font(.caption).foregroundStyle(ShellmateColors.textMuted); if on.wrappedValue { content() } }.padding(16).background(on.wrappedValue ? ShellmateColors.navy800.opacity(0.7) : ShellmateColors.navy800.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
    private func safeRow(_ l: String, _ d: String, _ on: Binding<Bool>) -> some View {
        HStack { VStack(alignment: .leading, spacing: 2) { Text(l).font(.callout).foregroundStyle(ShellmateColors.textPrimary); Text(d).font(.caption).foregroundStyle(ShellmateColors.textMuted) }; Spacer(); Toggle("", isOn: on).toggleStyle(.switch).tint(ShellmateColors.shell600) }.padding(12).background(on.wrappedValue ? ShellmateColors.navy800.opacity(0.3) : ShellmateColors.error.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 8))
    }
    private func save() async {
        saving = true; error = nil
        do { var c: ShellmateConfig; do { c = try cs.readConfig() } catch { c = ShellmateConfig() }
            var d: [String] = []; if !allowExec { d.append("exec") }; if !allowWrite { d.append("write") }; if !allowBrowser { d.append("browser") }
            c.capabilities.webSearch = webSearch; c.capabilities.webFetch = webFetch; c.capabilities.memory = memoryMode; c.capabilities.tools.deny = d
            if webSearch && !braveKey.isEmpty { KeychainHelper.save(service: "com.shellmate.api", account: "brave", value: braveKey) }
            if let i = c.agents.list.firstIndex(where: { $0.id == "main" }) { c.agents.list[i].tools.deny = d }
            try cs.writeConfig(c); saved = true
        } catch { self.error = error.localizedDescription }; saving = false
    }
}
