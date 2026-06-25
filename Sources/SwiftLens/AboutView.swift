import SwiftUI
import AppKit

// MARK: - 关于面板

/// 关于面板：图标 / 名称 / 版本 / 远程地址 / 开源许可证地址。
/// 优先从 Bundle.main 取版本，取不到（SPM `swift run` 无 Info.plist）则回落到默认值。
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let meta = AppMeta.shared

    var body: some View {
        VStack(spacing: 18) {
            // 图标 + 名称
            VStack(spacing: 12) {
                Image(nsImage: meta.appIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

                Text(meta.appName)
                    .font(.system(.title2, design: .default).bold())

                Text("version \(meta.versionString) (\(meta.buildString))")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(maxWidth: 320)

            // 可点击链接
            VStack(spacing: 10) {
                linkRow(
                    systemImage: "globe",
                    title: "Repository",
                    subtitle: meta.repositoryURL.absoluteString,
                    url: meta.repositoryURL
                )
                linkRow(
                    systemImage: "doc.text",
                    title: "License",
                    subtitle: meta.licenseName,
                    url: meta.licenseURL
                )
            }

            // 版权 / 备注
            Text(meta.copyright)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            Button(L10n.t(.close)) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 32)
        .padding(.top, 40)
        .padding(.bottom, 28)
        .frame(width: 440)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func linkRow(
        systemImage: String,
        title: String,
        subtitle: String,
        url: URL
    ) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(subtitle)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4)))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help("在浏览器中打开: \(url.absoluteString)")
    }
}

// MARK: - AppMeta

/// 应用元数据：从 Bundle.main 读取（Xcode 构建版本有 Info.plist），
/// 取不到时回落到默认值（SPM `swift run` 没有 Info.plist 的场景）。
final class AppMeta {
    static let shared = AppMeta()

    let appName: String
    let versionString: String       // CFBundleShortVersionString
    let buildString: String         // CFBundleVersion
    let repositoryURL: URL
    let licenseName: String
    let licenseURL: URL
    let copyright: String
    let appIcon: NSImage

    private init() {
        let bundle = Bundle.main

        // 名称
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? AppMeta.defaultAppName
        self.appName = name

        // 版本 / Build —— 取不到回落默认
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? AppMeta.defaultVersion
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? AppMeta.defaultBuild
        self.versionString = version
        self.buildString = build

        // 远程地址 / 许可证：默认值（SPM 拿不到，Xcode 项目里目前也未注入，
        // 需要时可在 Info.plist 加 CFBundleGetInfoString 或自定义键来覆盖）。
        let repoString = (bundle.object(forInfoDictionaryKey: "SwiftLensRepositoryURL") as? String)
            ?? AppMeta.defaultRepositoryURL.absoluteString
        let licenseString = (bundle.object(forInfoDictionaryKey: "SwiftLensLicenseURL") as? String)
            ?? AppMeta.defaultLicenseURL.absoluteString
        self.repositoryURL = URL(string: repoString) ?? AppMeta.defaultRepositoryURL
        self.licenseURL = URL(string: licenseString) ?? AppMeta.defaultLicenseURL
        self.licenseName = "MIT License"

        // 版权
        let cr = (bundle.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String)
            ?? AppMeta.defaultCopyright
        self.copyright = cr

        // 图标：Xcode 构建时 Assets.car 提供 AppIcon；SPM 工具模式下用 NSWorkspace 抓 bundle 图标，
        // 抓不到再回落到通用 "app" 占位图标。
        if let asset = NSImage(named: "AppIcon") {
            self.appIcon = asset
        } else {
            // 走 NSWorkspace 获取 bundle 的图标（对 .app bundle 路径会返回真实图标）
            let icon = NSWorkspace.shared.icon(forFile: bundle.bundleURL.path)
            // SPM 工具模式下 bundle.bundleURL 是裸可执行文件路径，icon 通常是通用可执行图标
            // 此时换用通用 "app" 系统图标
            if icon.size.width < 32 {
                // SPM 工具模式：用系统应用占位图标
                self.appIcon = NSImage(systemSymbolName: "app", accessibilityDescription: "App") 
                    ?? NSWorkspace.shared.icon(forFile: bundle.bundleURL.path)
            } else {
                self.appIcon = icon
            }
        }
    }

    // MARK: 默认值
    private static let defaultAppName        = "SwiftLens"
    private static let defaultVersion        = "1.0.0"
    private static let defaultBuild          = "1"
    private static let defaultRepositoryURL  = URL(string: "https://github.com/whybbe/SwiftLens")!
    private static let defaultLicenseURL     = URL(string: "https://github.com/whybbe/SwiftLens/blob/main/LICENSE")!
    private static let defaultCopyright      = "Copyright © 2026 0x574859. MIT License."
}

private extension Bundle {
    /// 占位 —— Bundle 没有原生 icon API，统一走 NSWorkspace 取图标。
}