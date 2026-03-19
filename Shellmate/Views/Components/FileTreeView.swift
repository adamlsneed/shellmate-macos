import SwiftUI
struct FileTreeView: View {
    let files: [GeneratedFile]; @State private var selectedFileId: String?
    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) { Image(systemName: "folder.fill").foregroundStyle(ShellmateColors.shell400); Text("~/.shellmate/workspace/").font(.system(.caption, design: .monospaced)).foregroundStyle(ShellmateColors.textSecondary) }.padding(.horizontal, 12).padding(.vertical, 8)
                Divider().background(ShellmateColors.navy700)
                ScrollView { LazyVStack(alignment: .leading, spacing: 0) { ForEach(files) { f in
                    Button(action: { selectedFileId = f.id }) {
                        HStack(spacing: 8) { Image(systemName: f.existsOnDisk ? "doc.badge.clock" : "doc.text.fill").font(.caption).foregroundStyle(f.existsOnDisk ? ShellmateColors.warning : ShellmateColors.shell400); Text(f.filename).font(.system(.caption, design: .monospaced)).foregroundStyle(ShellmateColors.textPrimary); Spacer(); if f.existsOnDisk { Text("exists").font(.caption2).foregroundStyle(ShellmateColors.warning) } }.padding(.horizontal, 12).padding(.vertical, 6).background(selectedFileId == f.id ? ShellmateColors.navy800 : .clear).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                } } }
            }.background(ShellmateColors.navy900).frame(minWidth: 200, idealWidth: 250)
            Group {
                if let sid = selectedFileId, let file = files.first(where: { $0.id == sid }) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack { Text(file.filename).font(.system(.caption, design: .monospaced).bold()).foregroundStyle(ShellmateColors.textPrimary); Spacer(); Text("\(file.content.count) chars").font(.caption2).foregroundStyle(ShellmateColors.textMuted) }.padding(.horizontal, 12).padding(.vertical, 8)
                        Divider().background(ShellmateColors.navy700)
                        ScrollView { Text(file.content).font(.system(.caption, design: .monospaced)).foregroundStyle(ShellmateColors.textSecondary).textSelection(.enabled).padding(12).frame(maxWidth: .infinity, alignment: .leading) }
                    }
                } else {
                    VStack { Image(systemName: "doc.text").font(.system(size: 32)).foregroundStyle(ShellmateColors.textMuted); Text("Select a file to preview").font(.caption).foregroundStyle(ShellmateColors.textMuted) }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.background(ShellmateColors.navy950).frame(minWidth: 300)
        }
    }
}
