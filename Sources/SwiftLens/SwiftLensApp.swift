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
        if info.lsUIElement == true { lines.append("形态: Agent App (无 Dock 图标)") }
        if info.lsBackgroundOnly == true { lines.append("形态: 仅后台运行 (LSBackgroundOnly)") }
        if info.isIOSPort { lines.append("形态: iOS 移植包 (含 UI* 键)") }
        // Sparkle 自动更新
        if let sp = info.extra.sparkle {
            lines.append("Sparkle 自动更新:")
            if let v = sp.feedURL { lines.append("  SUFeedURL: \(v)") }
            if let v = sp.publicEDKey { lines.append("  SUPublicEDKey: \(v)") }
            if let v = sp.publicDSAKeyFile { lines.append("  SUPublicDSAKeyFile: \(v)") }
            if let v = sp.enableAutomaticChecks { lines.append("  SUEnableAutomaticChecks: \(v)") }
            if let v = sp.scheduledCheckInterval {
                lines.append("  SUScheduledCheckInterval: \(v) 秒 (\(Double(v)/86400.0) 天)")
            }
            if let v = sp.allowsAutomaticUpdates { lines.append("  SUAllowsAutomaticUpdates: \(v)") }
            if let v = sp.enableInstallerLauncherService { lines.append("  SUEnableInstallerLauncherService: \(v)") }
            if let v = sp.enableDownloaderService { lines.append("  SUEnableDownloaderService: \(v)") }
            if let v = sp.showReleaseNotes { lines.append("  SUShowReleaseNotes: \(v)") }
            if let v = sp.enableSystemProfiling { lines.append("  SUEnableSystemProfiling: \(v)") }
            if let v = sp.sendProfileInfo { lines.append("  SUSendProfileInfo: \(v)") }
            if let v = sp.enableJavaScript { lines.append("  SUEnableJavaScript: \(v)") }
            if let v = sp.bundleName { lines.append("  SUBundleName: \(v)") }
        }
        // AppleScript / Siri
        let ex = info.extra
        if let v = ex.appleScriptEnabled { lines.append("NSAppleScriptEnabled: \(v)") }
        if let v = ex.scriptingDefinition { lines.append("OSAScriptingDefinition: \(v)") }
        if !ex.userActivityTypes.isEmpty {
            lines.append("NSUserActivityTypes: \(ex.userActivityTypes.joined(separator: ", "))")
        }
        if !ex.intentsSupported.isEmpty {
            lines.append("INIntentsSupported (Siri): \(ex.intentsSupported.joined(separator: ", "))")
        }
        if let v = ex.safariExtensionCorrespondingIOSApp {
            lines.append("SFSafariCorrespondingIOSAppBundleIdentifier: \(v)")
        }
        // iCloud
        if !ex.ubiquitousContainers.isEmpty {
            lines.append("iCloud Containers (\(ex.ubiquitousContainers.count) 项):")
            for (i, c) in ex.ubiquitousContainers.enumerated() {
                lines.append("  [\(i)] \(InfoPlistParser.flatten(c).map { "\($0.0)=\($0.1)" }.joined(separator: ", "))")
            }
        }
        // Notifications
        if let v = ex.userNotificationAlertStyle { lines.append("NSUserNotificationAlertStyle: \(v)") }
        if let v = ex.userNotificationsUsageDescription { lines.append("NSUserNotificationsUsageDescription: \(v)") }
        if let v = ex.localNotificationUsageDescription { lines.append("NSLocalNotificationUsageDescription: \(v)") }
        if let v = ex.remoteNotificationUsageDescription { lines.append("NSRemoteNotificationUsageDescription: \(v)") }
        // 杂项开关
        if let v = ex.supportsSuddenTermination { lines.append("NSSupportsSuddenTermination: \(v)") }
        if let v = ex.supportsAutomaticTermination { lines.append("NSSupportsAutomaticTermination: \(v)") }
        if let v = ex.lsRequiresCarbon { lines.append("LSRequiresCarbon: \(v)") }
        if let v = ex.lsRequiresNativeExecution { lines.append("LSRequiresNativeExecution: \(v)") }
        if let v = ex.lsMultipleInstancesProhibited { lines.append("LSMultipleInstancesProhibited: \(v)") }
        if let v = ex.lsHasLocalizedDisplayName { lines.append("LSHasLocalizedDisplayName: \(v)") }
        if let v = ex.lsFileQuarantineEnabled { lines.append("LSFileQuarantineEnabled: \(v)") }
        if let v = ex.gpuEjectPolicy { lines.append("GPUEjectPolicy: \(v)") }
        if let v = ex.gpuSelectionPolicy { lines.append("GPUSelectionPolicy: \(v)") }
        if let v = ex.itmsAppUsesNonExemptEncryption { lines.append("ITSAppUsesNonExemptEncryption: \(v)") }
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