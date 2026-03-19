import SwiftUI
struct SimpleCapabilities: View {
    var onDone: () -> Void; var onSkip: () -> Void
    @State private var expanded: String?; @State private var braveKey = ""; @State private var shellOn = false; @State private var saving = false; @State private var error: String?
    private let cs = ConfigService()
    private var hasChanges: Bool { !braveKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || shellOn }
    var body: some View {
        ScrollView { VStack(spacing: 24) {
            Image(systemName: "terminal.fill").font(.system(size: 40)).foregroundStyle(ShellmateColors.accent)
            Text("Extra features").font(.title2.bold()).foregroundStyle(ShellmateColors.textPrimary)
            Text("Optional -- set up now or later.").font(.callout).foregroundStyle(ShellmateColors.textSecondary)
            VStack(spacing: 12) {
                expSec("search", "magnifyingglass", "Web search", "Search the internet") { VStack(alignment: .leading, spacing: 12) { Text("Lets Shellmate look things up online.").font(.callout).foregroundStyle(ShellmateColors.textSecondary); SecureField("Brave Search key", text: $braveKey).textFieldStyle(.plain).foregroundStyle(ShellmateColors.textPrimary).padding(12).background(ShellmateColors.navy950).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(ShellmateColors.navy700, lineWidth: 2)) } }
                expSec("shell", "terminal", "Run commands", "Terminal commands for automation") { VStack(alignment: .leading, spacing: 12) { Text("Run commands on your Mac.").font(.callout).foregroundStyle(ShellmateColors.textSecondary); Button(action: { shellOn.toggle() }) { HStack { Text(shellOn ? "Enabled" : "Disabled").font(.callout.weight(.medium)).foregroundStyle(ShellmateColors.textPrimary); Spacer(); Toggle("", isOn: $shellOn).toggleStyle(.switch).tint(ShellmateColors.accent) }.padding(14).background(shellOn ? ShellmateColors.accent.opacity(0.1) : ShellmateColors.navy950).clipShape(RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain) } }
            }.frame(maxWidth: 500)
            if let error { Text(error).font(.callout).foregroundStyle(ShellmateColors.error) }
            VStack(spacing: 12) { if hasChanges { BigButton(saving ? "Saving..." : "Save and start", action: { Task { await save() } }).disabled(saving).frame(maxWidth: 500); Button("Skip") { onSkip() }.font(.callout).foregroundStyle(ShellmateColors.accent).buttonStyle(.plain) } else { BigButton("Start chatting", action: onSkip).frame(maxWidth: 500) } }
        }.padding(32) }
    }
    private func expSec<C: View>(_ id: String, _ icon: String, _ title: String, _ desc: String, @ViewBuilder content: () -> C) -> some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expanded = expanded == id ? nil : id } }) { HStack(spacing: 12) { Image(systemName: icon).font(.title3).foregroundStyle(ShellmateColors.accent); VStack(alignment: .leading, spacing: 2) { Text(title).font(.callout.bold()).foregroundStyle(ShellmateColors.textPrimary); Text(desc).font(.caption).foregroundStyle(ShellmateColors.textMuted) }; Spacer(); Image(systemName: expanded == id ? "minus" : "plus").foregroundStyle(ShellmateColors.textMuted) }.padding(16).contentShape(Rectangle()) }.buttonStyle(.plain)
            if expanded == id { Divider().background(ShellmateColors.navy700); content().padding(16) }
        }.background(ShellmateColors.surface).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(ShellmateColors.navy700, lineWidth: 2))
    }
    private func save() async {
        saving = true; error = nil
        do { var c: ShellmateConfig; do { c = try cs.readConfig() } catch { c = ShellmateConfig() }
            let bk = braveKey.trimmingCharacters(in: .whitespacesAndNewlines); c.capabilities.webSearch = !bk.isEmpty
            if !bk.isEmpty { KeychainHelper.save(service: "com.shellmate.api", account: "brave", value: bk) }; c.capabilities.webFetch = true
            if shellOn { c.capabilities.tools.deny = c.capabilities.tools.deny.filter { $0 != "exec" } }
            try cs.writeConfig(c); onDone()
        } catch { self.error = "Couldn't save." }; saving = false
    }
}
