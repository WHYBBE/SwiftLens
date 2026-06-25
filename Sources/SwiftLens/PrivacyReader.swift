import Foundation

// MARK: - 隐私权限描述 (TCC Usage Descriptions)

/// 提取 Info.plist 中所有 NS[Resource]UsageDescription 描述并归入分类。
struct PrivacyEntry: Identifiable {
    let id = UUID()
    let key: String
    let displayTitle: String
    let systemImage: String          // SF Symbol 名称
    let description: String          // Info.plist 里的描述串
}

enum PrivacyReader {
    // 已知的隐私/权限键映射到 (中文标题, SF Symbol)
    private static let descriptor: [String: (title: String, symbol: String)] = [
        // 通讯录 / 日历 / 提醒
        "NSContactsUsageDescription":         ("通讯录", "person.crop.circle"),
        "NSCalendarsUsageDescription":        ("日历", "calendar"),
        "NSCalendarsFullAccessUsageDescription": ("日历完整访问", "calendar.badge.clock"),
        "NSRemindersUsageDescription":        ("提醒事项", "list.bullet.rectangle"),
        "NSRemindersFullAccessUsageDescription": ("提醒事项完整访问", "list.bullet.rectangle.portrait"),
        // 位置
        "NSLocationUsageDescription":         ("位置", "location"),
        "NSLocationAlwaysUsageDescription":    ("位置 (始终)", "location.fill"),
        "NSLocationWhenInUseUsageDescription": ("位置 (使用时)", "location.viewfinder"),
        "NSLocationAlwaysAndWhenInUseUsageDescription": ("位置 (始终+使用时)", "location.fill.viewfinder"),
        "NSLocationDefaultAccuracyReduced":    ("位置精度 (降级)", "location.slash"),
        // 媒体捕获
        "NSCameraUsageDescription":           ("相机", "camera"),
        "NSMicrophoneUsageDescription":       ("麦克风", "mic"),
        "NSAudioCaptureUsageDescription":     ("音频捕获", "waveform"),
        // 蓝牙
        "NSBluetoothAlwaysUsageDescription":  ("蓝牙 (始终)", "antenna.radiowaves.left.and.right"),
        "NSBluetoothPeripheralUsageDescription": ("蓝牙外设", "antenna.radiowaves.left.and.right"),
        // 健康 / HomeKit / Motion
        "NSHealthShareUsageDescription":      ("健康共享", "heart"),
        "NSHealthClinicalHealthRecordsShareUsageDescription": ("健康临床记录", "heart.text.squarefill"),
        "NSHealthUpdateUsageDescription":     ("健康更新", "heart.arrow.circlepath"),
        "NSHomeKitUsageDescription":          ("HomeKit", "house"),
        "NSMotionUsageDescription":           ("运动与健身", "figure.walk"),
        "NSExtensionUsageDescription":        ("扩展 (Extensions)", "puzzlepiece.extension"),
        // 媒体库 / Photos
        "NSAppleMusicUsageDescription":       ("Apple Music", "music.note"),
        "NSPhotoLibraryUsageDescription":     ("照片库", "photo"),
        "NSPhotoLibraryAddUsageDescription":  ("照片库 (添加)", "photo.badge.plus"),
        "NSCameraReactionEffectGesturesEnabledDefault": ("相机反应手势", "camera.turn.left"),
        // 语音 / Siri
        "NSSpeechRecognitionUsageDescription": ("语音识别", "waveform.badge.magnifyingglass"),
        "NSSiriUsageDescription":             ("Siri", "siri"),
        // 网络卷 / 文件 / 文件夹
        "NSFilesDownloadedUsageDescription":  ("下载文件夹", "arrow.down.circle"),
        // Apple Events / Automation
        "NSAppleEventsUsageDescription":      ("Apple 事件 (自动化)", "applescript"),
        "NSSystemAdministrationUsageDescription": ("系统管理 (特权)", "lock.shield"),
        // 媒体的另外几类
        "NSVideoSubscriberAccountUsageDescription": ("视频订阅账号", "tv"),
        // AVP spatial
        "NSCameraCaptureUsageDescription":    ("相机捕获", "camera.viewfinder"),
        // Face ID / Health extras (Motion 已在健康区中)
        "NSFaceIDUsageDescription":           ("Face ID", "faceid"),
        // 系统扩展 / 屏幕捕获
        "NSSystemExtensionUsageDescription": ("系统扩展", "puzzlepiece.extension"),
        "NSScreenCaptureUsageDescription":   ("屏幕捕获", "rectangle.dashed"),
        // FileProvider / 通知
        "NSFileProviderDomainUsageDescription": ("文件提供者域", "folder.fill.badge.plus"),
        "NSUserNotificationsUsageDescription": ("用户通知", "bell"),
        "NSLocalNotificationUsageDescription": ("本地通知", "bell.badge"),
        "NSRemoteNotificationUsageDescription": ("远程通知", "bell.badge.wifi"),
        // 自动填充 / 安全 / 升级
        "NSAutoFillRequiresTextContentTypeForOneTimeCodeOnMac": ("自动填充 (验证码)", "text.badge.checkmark"),
        "NSUpdateSecurityPolicy":            ("更新安全策略", "lock.shield"),
        // 临时位置
        "NSLocationTemporaryUsageDescriptionDictionary": ("位置临时使用 (字典)", "location.tor"),
        // 共享/通讯组
        "NSContactsAddUsageDescription":      ("通讯录 (添加)", "person.badge.plus"),
        "NSContactsCardUsageDescription":     ("联系人卡片", "person.crop.rectangle"),
        // Keyboard
        "NSInputAssistantUsageDescription":   ("输入助手", "keyboard"),
        // File access
        "NSDesktopFolderUsageDescription":    ("桌面文件夹", "desktopcomputer"),
        "NSDocumentsFolderUsageDescription":  ("文稿文件夹", "folder"),
        "NSDownloadsFolderUsageDescription":  ("下载文件夹", "arrow.down.circle"),
        "NSNetworkVolumesUsageDescription":   ("网络卷", "network"),
        "NSRemovableVolumesUsageDescription": ("可移动卷", "externaldrive"),
        // Service
        "NSServicesUsageDescription":         ("服务 (Services)", "wrench.adjustable"),
        // 通用键兜底 —— 任何 "NS<Name>UsageDescription" 但未在上述列表中的
        // 由 parse 时用 default fallback 处理
    ]

    /// 兜底解析：键以 "UsageDescription" 结尾且未在 descriptor 中时，仍尝试生成条目。
    static func parse(from plist: [String: Any]) -> [PrivacyEntry] {
        var results: [PrivacyEntry] = []
        for key in plist.keys.sorted() {
            let isUsageKey = key.hasSuffix("UsageDescription")
            let value: String
            if let s = plist[key] as? String { value = s }
            else { value = InfoPlistParser.describe(plist[key] ?? "") }
            if let meta = descriptor[key] {
                results.append(PrivacyEntry(
                    key: key,
                    displayTitle: meta.title,
                    systemImage: meta.symbol,
                    description: value
                ))
            } else if isUsageKey {
                // 自动从 key 派生显示名
                let title = key
                    .replacingOccurrences(of: "NS", with: "")
                    .replacingOccurrences(of: "UsageDescription", with: "")
                    .replacingOccurrences(of: "Always", with: " (始终)")
                    .replacingOccurrences(of: "WhenInUse", with: " (使用时)")
                results.append(PrivacyEntry(
                    key: key,
                    displayTitle: title.isEmpty ? key : title,
                    systemImage: "questionmark.shield",
                    description: value
                ))
            }
        }
        return results
    }
}