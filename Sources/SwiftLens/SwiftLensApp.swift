import SwiftUI
import AppKit

// MARK: - 应用入口

@main
struct SwiftLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("SwiftLens") {
            ContentView()
                .frame(minWidth: 960, minHeight: 640)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // 隐藏 CLI 模式：传入一个 .app 路径作为参数时，直接打印摘要并退出。
        let args = CommandLine.arguments
        if args.count >= 2, args[1].hasSuffix(".app"),
           FileManager.default.fileExists(atPath: args[1]) {
            let info = AppInfoLoader.load(url: URL(fileURLWithPath: args[1]))
            print(summary(for: info))
            exit(0)
        }

        // SPM `swift run` 启动的可执行文件没有 Info.plist，
        // 默认是 .accessory 策略 —— 无 Dock 图标、无窗口聚焦。
        // 改为常规 App 策略并在启动后主动激活，使窗口出现在 Dock 并取得焦点。
        let app = (notification.object as? NSApplication) ?? NSApp
        app?.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 应用启动完成后主动激活为前台应用，确保窗口立即获得焦点。
        NSApp.activate(ignoringOtherApps: true)
    }

    private func summary(for info: AppInfo) -> String {
        var lines: [String] = []
        lines.append("# \(info.displayName ?? info.bundleName ?? info.bundleURL.lastPathComponent)")
        lines.append("路径: \(info.bundleURL.path)")
        lines.append("BundleID: \(info.bundleIdentifier ?? "—")")
        lines.append("版本: \(info.bundleShortVersion ?? "—") (\(info.bundleVersion ?? "—"))")
        lines.append("最低系统版本: \(info.minimumOSVersion ?? "—")")
        lines.append("SDK: \(info.sdkVersion ?? "—") / \(info.platformName ?? "—") \(info.sdkBuild ?? "")")
        lines.append("Info.plist keys: \(info.flatRows.count) 项")
        lines.append("架构: \(info.architectures.map { "\($0.name)(\($0.bits)-bit, \($0.cpuType))" }.joined(separator: ", "))")
        if !info.supportedPlatforms.isEmpty {
            lines.append("支持平台: \(info.supportedPlatforms.joined(separator: ", "))")
        }
        if let p = info.principalClass { lines.append("NSPrincipalClass: \(p)") }
        if let c = info.humanReadableCopyright { lines.append("版权: \(c)") }
        lines.append("URL Schemes: \(info.urlSchemes.isEmpty ? "—" : info.urlSchemes.joined(separator: ", "))")
        lines.append("文档类型: \(info.documentTypes.count) 项")
        let cs = info.codeSign
        lines.append("签名: \(cs.state.rawValue) — \(cs.validity.rawValue) — \(cs.notarization.rawValue)")
        if let v = cs.format { lines.append("  Format: \(v)") }
        if let v = cs.identifier { lines.append("  Identifier: \(v)") }
        if let v = cs.teamIdentifier { lines.append("  TeamIdentifier: \(v)") }
        if let v = cs.cdHash { lines.append("  CDHash: \(v)") }
        if let v = cs.hashType { lines.append("  HashType: \(v)") }
        if let v = cs.signatureType { lines.append("  Signature: \(v)") }
        if let v = cs.runtimeVersion { lines.append("  Runtime Version: \(v)") }
        if !cs.decodedFlags.isEmpty { lines.append("  flags(解码): \(cs.decodedFlags.joined(separator: ", "))") }
        if let v = cs.flags { lines.append("  flags(原始): \(v)") }
        if let v = cs.sealedResourcesVersion {
            var sealed = "version=\(v)"
            if let r = cs.sealedResourcesRules { sealed += " rules=\(r)" }
            if let f = cs.sealedResourcesFiles { sealed += " files=\(f)" }
            lines.append("  Sealed Resources: \(sealed)")
        }
        if !cs.authorities.isEmpty {
            lines.append("  Authority:")
            cs.authorities.forEach { lines.append("    - \($0)") }
        }
        if let ent = cs.entitlements {
            lines.append("  Entitlements (\(ent.count) 项):")
            InfoPlistParser.flatten(ent).sorted { $0.0 < $1.0 }
                .forEach { lines.append("    \($0.0) = \($0.1)") }
        } else {
            lines.append("  Entitlements: 无")
        }
        lines.append("隐私权限描述: \(info.privacyEntries.count) 项")
        for e in info.privacyEntries.prefix(8) {
            lines.append("  · \(e.displayTitle) [\(e.key)]: \(e.description)")
        }
        if info.privacyEntries.count > 8 {
            lines.append("  ... 另外 \(info.privacyEntries.count - 8) 项")
        }
        if info.appTransportSecurity != nil { lines.append("ATS: 已声明 NSAppTransportSecurity") }
        if info.electronAsarIntegrity != nil { lines.append("Electron: 已声明 ElectronAsarIntegrity") }
        if let q = info.quarantine {
            lines.append("Quarantine: flags=\(q.flags) agent=\(q.agent) 时间=\(q.timestampString) 日期=\(q.downloadDate.map { ISO8601DateFormatter().string(from: $0) } ?? "—")")
        } else {
            lines.append("Quarantine: 无")
        }
        if !info.extendedXattrs.names.isEmpty {
            lines.append("扩展属性 (xattrs): \(info.extendedXattrs.names.joined(separator: ", "))")
        }
        lines.append("子 bundle: \(info.subBundles.count) 项 (\(ByteCountFormatter.string(fromByteCount: Int64(info.subBundlesTotalSize), countStyle: .file)))")
        for sub in info.subBundles.prefix(8) {
            lines.append("  · [\(sub.kind.rawValue)] \(sub.relativePath) — \(sub.bundleIdentifier ?? "—") (\(sub.signatureState.rawValue))")
        }
        if info.subBundles.count > 8 {
            lines.append("  ... 另外 \(info.subBundles.count - 8) 项")
        }
        lines.append("文件大小: \(info.formattedFileSize()) (\(info.fileSize) 字节)")
        return lines.joined(separator: "\n")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}