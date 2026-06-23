import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 主界面 — 即用即走：拖入或选择一个 .app bundle 直接展示详情。
struct ContentView: View {
    @State private var info: AppInfo?
    @State private var loading: Bool = false
    @State private var dropHover: Bool = false
    @State private var lastError: String?

    var body: some View {
        Group {
            if let info = info {
                DetailView(info: info)
            } else {
                placeholder
            }
        }
        .overlay {
            if loading { ProgressView("正在分析 .app …").controlSize(.large) }
        }
        .background(
            // 整窗拖放接收器
            DropZoneView(
                isHovered: $dropHover,
                onDrop: { url in handle(url: url) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { openPanel() } label: {
                    Label("打开 .app", systemImage: "folder.badge.plus")
                }
                if info != nil {
                    Button { reset() } label: {
                        Label("清空", systemImage: "arrow.uturn.backward")
                    }
                }
            }
        }
        .navigationTitle(info?.bundleURL.lastPathComponent ?? "SwiftLens")
    }

    private var placeholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.badge")
                .font(.system(size: 72))
                .foregroundStyle(dropHover ? Color.accentColor : Color.secondary)
            Text(dropHover ? "松开以加载" : "拖入 .app 到此处")
                .font(.title2.bold())
                .foregroundStyle(dropHover ? Color.accentColor : Color.primary)
            Text("或点击右上角 “打开 .app” 选择")
                .font(.callout)
                .foregroundStyle(.secondary)
            if let err = lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    dropHover ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
                .padding(dropHover ? 8 : 24)
        )
    }

    // MARK: - Actions
    private func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.title = "选择 .app bundle"
        if panel.runModal() == .OK, let url = panel.url {
            handle(url: url)
        }
    }

    private func handle(url: URL) {
        guard url.pathExtension == "app" else {
            lastError = "不是 .app bundle: \(url.lastPathComponent)"
            return
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            lastError = "文件不存在: \(url.path)"
            return
        }
        lastError = nil
        loading = true
        let work = url
        DispatchQueue.global(qos: .userInitiated).async {
            let result = AppInfoLoader.load(url: work)
            DispatchQueue.main.async {
                self.info = result
                self.loading = false
            }
        }
    }

    private func reset() {
        info = nil
        lastError = nil
    }
}

// MARK: - DropZoneView
private struct DropZoneView: NSViewRepresentable {
    @Binding var isHovered: Bool
    let onDrop: (URL) -> Void

    func makeNSView(context: Context) -> DropNSView {
        let v = DropNSView()
        v.onDrop = onDrop
        v.onHoverChange = { isHovered = $0 }
        return v
    }

    func updateNSView(_ nsView: DropNSView, context: Context) {
        nsView.onDrop = onDrop
        nsView.onHoverChange = { isHovered = $0 }
    }
}

private final class DropNSView: NSView {
    var onDrop: ((URL) -> Void)?
    var onHoverChange: ((Bool) -> Void)?

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let ok = extractedURL(from: sender) != nil
        onHoverChange?(ok)
        return ok ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let ok = extractedURL(from: sender) != nil
        return ok ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onHoverChange?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = extractedURL(from: sender) else { return false }
        onHoverChange?(false)
        onDrop?(url)
        return true
    }

    private func extractedURL(from sender: NSDraggingInfo) -> URL? {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              let url = urls.first else { return nil }
        return url.pathExtension == "app" ? url : nil
    }
}