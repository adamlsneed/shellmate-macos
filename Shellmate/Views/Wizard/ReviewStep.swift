import SwiftUI
struct ReviewStep: View {
    @Environment(WizardState.self) private var wizardState; @State private var showRaw = false
    private var hasAgent: Bool { !wizardState.agentSpec.name.isEmpty || !wizardState.agentSpec.mission.isEmpty }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            if !hasAgent { warn("No spec yet. Go back to continue the conversation.") }
            if wizardState.agentSpec.never.count < 2 && hasAgent { warn("Consider adding safety rules.") }
            if hasAgent { agentCard }
            if showRaw, let d = try? JSONEncoder().encode(wizardState.agentSpec), let s = String(data: d, encoding: .utf8) {
                ScrollView(.horizontal) { Text(s).font(.system(.caption, design: .monospaced)).foregroundStyle(ShellmateColors.success).textSelection(.enabled).padding(12) }.frame(maxHeight: 200).background(ShellmateColors.navy950).clipShape(RoundedRectangle(cornerRadius: 10)) }
            Button(showRaw ? "Hide details" : "Show details") { showRaw.toggle() }.font(.caption).foregroundStyle(ShellmateColors.textMuted).buttonStyle(.plain)
            HStack(spacing: 12) { BigButton("Go back", icon: "arrow.left", style: .secondary) { wizardState.previousPhase() }.frame(maxWidth: 160); BigButton("Generate files", icon: "arrow.right") { wizardState.nextPhase() } }
        }.padding(24) }
    }
    private var agentCard: some View {
        @Bindable var s = wizardState
        return VStack(alignment: .leading, spacing: 16) {
            TextField("Name", text: $s.agentSpec.name).font(.title3.bold()).foregroundStyle(ShellmateColors.textPrimary).textFieldStyle(.plain)
            if !wizardState.agentSpec.personality.isEmpty { lbl("Personality"); TextEditor(text: $s.agentSpec.personality).font(.callout).foregroundStyle(ShellmateColors.textSecondary).scrollContentBackground(.hidden).frame(minHeight: 50) }
            lbl("Mission"); TextEditor(text: $s.agentSpec.mission).font(.callout).foregroundStyle(ShellmateColors.textSecondary).scrollContentBackground(.hidden).frame(minHeight: 50)
            if !wizardState.agentSpec.macApps.isEmpty { lbl("Mac Apps"); tagList($s.agentSpec.macApps) }
            if !wizardState.agentSpec.useCases.isEmpty { lbl("Use Cases"); itemList($s.agentSpec.useCases) }
            Divider().background(ShellmateColors.navy700)
            lbl("Will Never"); ruleList($s.agentSpec.never)
        }.padding(20).background(ShellmateColors.navy800).clipShape(RoundedRectangle(cornerRadius: 12))
    }
    private func lbl(_ t: String) -> some View { Text(t.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(ShellmateColors.textMuted).tracking(1) }
    private func warn(_ t: String) -> some View { Text(t).font(.caption).foregroundStyle(ShellmateColors.warning).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(ShellmateColors.warning.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10)) }
    private func tagList(_ items: Binding<[String]>) -> some View {
        FlowLayout(spacing: 6) { ForEach(Array(items.wrappedValue.enumerated()), id: \.offset) { i, item in HStack(spacing: 4) { Text(item).font(.caption).foregroundStyle(ShellmateColors.shell300); Button(action: { items.wrappedValue.remove(at: i) }) { Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(ShellmateColors.textMuted) }.buttonStyle(.plain) }.padding(.horizontal, 10).padding(.vertical, 4).background(ShellmateColors.shell600.opacity(0.15)).clipShape(Capsule()) } }
    }
    private func itemList(_ items: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 4) { ForEach(Array(items.wrappedValue.enumerated()), id: \.offset) { i, item in HStack { Image(systemName: "circle.fill").font(.system(size: 6)).foregroundStyle(ShellmateColors.shell500).padding(.top, 6); Text(item).font(.callout).foregroundStyle(ShellmateColors.textSecondary); Spacer(); Button(action: { items.wrappedValue.remove(at: i) }) { Image(systemName: "xmark").font(.caption2).foregroundStyle(ShellmateColors.textMuted) }.buttonStyle(.plain).opacity(0.5) } } }
    }
    private func ruleList(_ rules: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 4) { ForEach(Array(rules.wrappedValue.enumerated()), id: \.offset) { i, rule in HStack { Image(systemName: "xmark").font(.caption2.bold()).foregroundStyle(ShellmateColors.error.opacity(0.7)).padding(.top, 4); Text(rule).font(.caption).foregroundStyle(ShellmateColors.error.opacity(0.8)); Spacer(); Button(action: { rules.wrappedValue.remove(at: i) }) { Image(systemName: "trash").font(.caption2).foregroundStyle(ShellmateColors.textMuted) }.buttonStyle(.plain).opacity(0.5) } } }
    }
}
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { arrange(proposal: proposal, subviews: subviews).1 }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) { let r = arrange(proposal: proposal, subviews: subviews); for (i, p) in r.0.enumerated() { subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified) } }
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ([CGPoint], CGSize) {
        let mw = proposal.width ?? .infinity; var ps: [CGPoint] = []; var x: CGFloat = 0; var y: CGFloat = 0; var lh: CGFloat = 0; var tw: CGFloat = 0; var th: CGFloat = 0
        for sv in subviews { let s = sv.sizeThatFits(.unspecified); if x + s.width > mw && x > 0 { x = 0; y += lh + spacing; lh = 0 }; ps.append(CGPoint(x: x, y: y)); lh = max(lh, s.height); x += s.width + spacing; tw = max(tw, x - spacing); th = max(th, y + lh) }
        return (ps, CGSize(width: tw, height: th))
    }
}
