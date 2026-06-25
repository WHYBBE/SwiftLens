import Foundation

// MARK: - 运行时本地化 (zh / en)

/// 极简的运行时字符串本地化表。
/// 设置面板切换语言时，AppState.language 改变 -> 所有依赖 L10n 的视图刷新。
enum L10n {

    /// 已支持的 key，与下面两张表一一对应。
    enum Key: String {
        // 设置
        case settings
        case language
        case theme
        case langSystem
        case langZh
        case langEn
        case themeSystem
        case themeLight
        case themeDark
        case close
        // 顶部工具栏 / 通用
        case appName
        case openApp
        case clear
        case revealInFinder
        case copySummary
        case placeholderOpen
        case placeholderDrop
        case placeholderRelease
        case placeholderPick
        // 头部徽标
        case badgeIsolated
        case badgeNoQuarantine
        case badgeAgentApp
        case badgeBackground
        case badgeIOSPort
        // 分区标题
        case basicInfo
        case runtime
        case architectures
        case documentTypes
        case urlSchemes
        case privacy
        case ats
        case quarantine
        case xattrs
        case codeSigning
        case entitlements
        case subBundles
        case sparkle
        case appleScriptSiri
        case icloud
        case notifications
        case behaviors
        case localization
        case iosPortFields
        case buildMetadata
        case bonjour
        case fileInfo
        case rawPlist
        case rawCodesign
        // 文档类型 row inner
        case extName
        case prioLogo
        case utis
        case prioKey
        case iconFile
        // 隐私 / 计数提示
        case noneDocType
        case noneXattrs
        // CLI/其它
        case invalidApp
        case fileMissing
        case analyzing
    }

    /// 中文表
    private static let zh: [Key: String] = [
        .settings: "设置", .language: "语言", .theme: "主题",
        .langSystem: "跟随系统", .langZh: "中文", .langEn: "English",
        .themeSystem: "跟随系统", .themeLight: "浅色", .themeDark: "深色",
        .close: "关闭",
        .appName: "SwiftLens", .openApp: "打开 .app", .clear: "清空",
        .revealInFinder: "在访达中显示", .copySummary: "复制摘要",
        .placeholderOpen: "拖入 .app 到此处", .placeholderDrop: "拖入 .app 到此处",
        .placeholderRelease: "松开以加载", .placeholderPick: "或点击右上角 “打开 .app” 选择",
        .badgeIsolated: "已隔离", .badgeNoQuarantine: "无隔离",
        .badgeAgentApp: "Agent App (无 Dock)", .badgeBackground: "仅后台 (Background)",
        .badgeIOSPort: "iOS 移植包",
        .basicInfo: "基本信息", .runtime: "运行环境 & 部署",
        .architectures: "架构 (Mach-O)", .documentTypes: "文档类型 (CFBundleDocumentTypes)",
        .urlSchemes: "URL Schemes", .privacy: "隐私权限描述 (TCC Usage Descriptions)",
        .ats: "网络安全 / ATS · Electron", .quarantine: "Quarantine 隔离标记",
        .xattrs: "扩展属性 (xattrs)", .codeSigning: "代码签名 (Code Signing)",
        .entitlements: "Entitlements 权限", .subBundles: "内嵌子 bundle",
        .sparkle: "Sparkle 自动更新", .appleScriptSiri: "AppleScript / Siri / Intents",
        .icloud: "iCloud (NSUbiquitousContainers)", .notifications: "通知 (Notifications)",
        .behaviors: "杂项开关 (生命周期 / 加密合规 / GPU)",
        .localization: "帮助 / 本地化 / Accent / Spotlight",
        .iosPortFields: "iOS 移植包字段 (UI* 键)", .buildMetadata: "Electron / 构建元数据 / 厂商",
        .bonjour: "Bonjour 服务发现 (NSBonjourServices)",
        .fileInfo: "文件信息", .rawPlist: "Info.plist 完整内容", .rawCodesign: "codesign 原始输出",
        .extName: "扩展名", .prioLogo: "优先级", .utis: "UTIs", .prioKey: "优先级",
        .iconFile: "图标文件", .noneDocType: "未声明自定义文档类型",
        .noneXattrs: "无任何扩展属性", .invalidApp: "不是 .app bundle",
        .fileMissing: "文件不存在", .analyzing: "正在分析 .app …"
    ]

    /// 英文表（缺失时回退到 zh key 字面名）
    private static let en: [Key: String] = [
        .settings: "Settings", .language: "Language", .theme: "Theme",
        .langSystem: "Follow System", .langZh: "中文", .langEn: "English",
        .themeSystem: "Follow System", .themeLight: "Light", .themeDark: "Dark",
        .close: "Close",
        .appName: "SwiftLens", .openApp: "Open .app", .clear: "Clear",
        .revealInFinder: "Reveal in Finder", .copySummary: "Copy Summary",
        .placeholderOpen: "Drop .app here", .placeholderDrop: "Drop .app here",
        .placeholderRelease: "Release to load", .placeholderPick: "or click “Open .app” at top right",
        .badgeIsolated: "Quarantined", .badgeNoQuarantine: "No Quarantine",
        .badgeAgentApp: "Agent App (no Dock)", .badgeBackground: "Background-only",
        .badgeIOSPort: "iOS port",
        .basicInfo: "Basic", .runtime: "Runtime & Deployment",
        .architectures: "Architectures (Mach-O)", .documentTypes: "Document Types (CFBundleDocumentTypes)",
        .urlSchemes: "URL Schemes", .privacy: "Privacy (TCC Usage Descriptions)",
        .ats: "Network Security / ATS · Electron", .quarantine: "Quarantine Flag",
        .xattrs: "Extended Attributes (xattrs)", .codeSigning: "Code Signing",
        .entitlements: "Entitlements", .subBundles: "Embedded Sub Bundles",
        .sparkle: "Sparkle Auto Update", .appleScriptSiri: "AppleScript / Siri / Intents",
        .icloud: "iCloud (NSUbiquitousContainers)", .notifications: "Notifications",
        .behaviors: "Misc Switches (Lifecycle / Crypto / GPU)",
        .localization: "Help / Localization / Accent / Spotlight",
        .iosPortFields: "iOS port fields (UI* keys)", .buildMetadata: "Electron / Build metadata / Vendor",
        .bonjour: "Bonjour (NSBonjourServices)",
        .fileInfo: "File Info", .rawPlist: "Info.plist (raw)", .rawCodesign: "codesign (raw)",
        .extName: "Extensions", .prioLogo: "Rank", .utis: "UTIs", .prioKey: "Rank",
        .iconFile: "Icon file", .noneDocType: "No custom document type declared",
        .noneXattrs: "No extended attributes", .invalidApp: "Not an .app bundle",
        .fileMissing: "File not found", .analyzing: "Analyzing .app …"
    ]

    /// 当前生效语言（system 时按系统首选判断）。
    private static var current: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: "swiftlens.language") ?? AppLanguage.system.rawValue
        let lang = AppLanguage(rawValue: raw) ?? .system
        switch lang {
        case .zh: return .zh
        case .en: return .en
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("zh") ? .zh : .en
        }
    }

    /// 查询字符串。注意：因为不依赖 SwiftUI 环境，调用者需要让视图依赖 AppState.language 以便刷新。
    static func t(_ key: Key) -> String {
        switch current {
        case .zh, .system: return zh[key] ?? key.rawValue
        case .en:          return en[key] ?? zh[key] ?? key.rawValue
        }
    }
}