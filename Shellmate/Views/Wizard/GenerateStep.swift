import SwiftUI
struct GenerateStep: View {
    @Environment(WizardState.self) private var wizardState
    @State private var isGenerating = false; @State private var isWriting = false; @State private var writeComplete = false; @State private var configMerged = false; @State private var conflicts: [String] = []; @State private var forceOverwrite = false; @State private var error: String?; @State private var writtenCount = 0
    private let ws = WorkspaceService(); private let cs = ConfigService()
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            if isGenerating { HStack(spacing: 8) { LoadingSpinner(); Text("Generating...").font(.callout).foregroundStyle(ShellmateColors.shell400) } }
            else if !wizardState.generatedFiles.isEmpty {
                FileTreeView(files: wizardState.generatedFiles).frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(ShellmateColors.navy700, lineWidth: 1))
                if !conflicts.isEmpty && !writeComplete { VStack(alignment: .leading, spacing: 8) { Text("Existing workspace detected").font(.callout.bold()).foregroundStyle(ShellmateColors.warning); Toggle(isOn: $forceOverwrite) { Text("Overwrite (backs up .bak)").font(.caption).foregroundStyle(ShellmateColors.warning) }.toggleStyle(.checkbox) }.padding(16).background(ShellmateColors.warning.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10)) }
                if writeComplete { VStack(alignment: .leading, spacing: 8) { HStack(spacing: 6) { Image(systemName: "checkmark.circle.fill").foregroundStyle(ShellmateColors.success); Text("Written \(writtenCount) files").font(.callout).foregroundStyle(ShellmateColors.textSecondary) }; if configMerged { HStack(spacing: 6) { Image(systemName: "checkmark.circle.fill").foregroundStyle(ShellmateColors.success); Text("Registered in config").font(.callout).foregroundStyle(ShellmateColors.textSecondary) } } }.padding(16).background(ShellmateColors.navy800).clipShape(RoundedRectangle(cornerRadius: 10)) }
                if let error { Text(error).font(.caption).foregroundStyle(ShellmateColors.error) }
                HStack(spacing: 12) { if !writeComplete { BigButton("Regenerate", icon: "arrow.clockwise", style: .secondary) { Task { await gen() } }.frame(maxWidth: 180); BigButton(isWriting ? "Writing..." : "Write files", icon: "square.and.arrow.down") { Task { await write() } }.disabled(isWriting || (!forceOverwrite && !conflicts.isEmpty)) }; if writeComplete { BigButton("Capabilities", icon: "arrow.right") { wizardState.nextPhase() } } }
            }
        }.padding(24) }.task { if wizardState.generatedFiles.isEmpty { await gen() } }
    }
    private func gen() async {
        isGenerating = true; error = nil; var f = GeneratorService.generateAll(agent: wizardState.agentSpec); var c: [String] = []
        for i in f.indices { if ws.fileExists(name: f[i].filename) { f[i].existsOnDisk = true; c.append(f[i].filename) } }
        wizardState.generatedFiles = f; conflicts = c; isGenerating = false
    }
    private func write() async {
        isWriting = true; error = nil
        do { try cs.ensureWorkspace(); var w = 0; for f in wizardState.generatedFiles { if f.existsOnDisk && !forceOverwrite { continue }; try ws.writeFile(name: f.filename, content: f.content); w += 1 }; writtenCount = w
            var cfg: ShellmateConfig; do { cfg = try cs.readConfig() } catch { cfg = ShellmateConfig() }
            cfg.agents.list = [AgentListEntry(id: "main", name: wizardState.agentSpec.name, workspace: "~/.shellmate/workspace")]
            try cs.writeConfig(cfg); configMerged = true; writeComplete = true
        } catch { self.error = error.localizedDescription }; isWriting = false
    }
}
