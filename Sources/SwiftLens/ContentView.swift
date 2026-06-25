import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 主界面 — 即用即走：拖入或选择一个 .app bundle 直接展示详情。
struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var info: AppInfo?
    @State private var loading: Bool = false
    @State private var dropHover: Bool = false
    @State private var lastError: String?
    @State private var showSettings: Bool = false
    @State private var spinnerSpin: Bool = false   // 持续旋转的触发开关

    var body: some View {
        Group {
            if let info = info {
                DetailView(info: info)
                    .id(appState.language.rawValue)
            } else {
                placeholder
                    .opacity(loading ? 0 : 1)      // 加载时隐藏占位避免与 ProgressView 重叠
                    .id(appState.language.rawValue)
            }
        }
        .overlay {
            if loading { loadingOverlay }
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
                    Label(L10n.t(.openApp), systemImage: "folder.badge.plus")
                }
                if info != nil {
                    Button { reset() } label: {
                        Label(L10n.t(.clear), systemImage: "arrow.uturn.backward")
                    }
                }
                Button { showSettings = true } label: {
                    Label(L10n.t(.settings), systemImage: "gearshape")
                }
            }
        }
        .navigationTitle(info?.bundleURL.lastPathComponent ?? L10n.t(.appName))
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
                .id(appState.language.rawValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showSettings = true
        }
    }

    private var placeholder: some View {
        VStack(spacing: 22) {
            Image(systemName: "app.badge")
                .font(.system(size: 110, weight: .light))
                .foregroundStyle(dropHover ? Color.accentColor : Color.secondary)
                .scaleEffect(dropHover ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 0.25), value: dropHover)
            Text(dropHover ? L10n.t(.placeholderRelease) : L10n.t(.placeholderDrop))
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(dropHover ? Color.accentColor : Color.primary)
            Text(L10n.t(.placeholderPick))
                .font(.system(.body))
                .foregroundStyle(.secondary)
            if let err = lastError {
                Text(err)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    dropHover ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .padding(dropHover ? 8 : 28)
        )
        .transition(.opacity)
    }

    // MARK: - 加载遮罩
    private var loadingOverlay: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(spinnerSpin ? 360 : 0))   // 持续旋转
                    .animation(
                        .linear(duration: 0.9)
                            .repeatForever(autoreverses: false),
                        value: spinnerSpin
                    )
            }
            .frame(width: 96, height: 96)
            Text(L10n.t(.analyzing))
                .font(.system(.title3, design: .default).bold())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .transition(.opacity)
        .onAppear {
            // appear 时启动连续旋转；下一 runloop 再翻转，避免初值 0 与最终值相同被 SwiftUI 优化掉
            DispatchQueue.main.async { spinnerSpin = true }
        }
        .onDisappear { spinnerSpin = false }
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