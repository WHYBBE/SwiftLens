import Foundation

// MARK: - 其它"杂项高价值"信息

/// 把 Info.plist 中跨多次扫描发现的若干高价值键集中抽取出来，
/// 用于「Sparkle 自动更新 / AppleScript / Siri / iCloud / 通知 / 开关」等分区。
struct ExtraInfo {
    // A. Sparkle (SUFeedURL/SUPublicEDKey/...)
    let sparkle: SparkleInfo?

    struct SparkleInfo {
        let feedURL: String?                  // SUFeedURL
        let publicEDKey: String?              // SUPublicEDKey (ed25519 公钥)
        let publicDSAKeyFile: String?         // SUPublicDSAKeyFile
        let enableAutomaticChecks: Bool?
        let scheduledCheckInterval: Int?      // 秒
        let allowsAutomaticUpdates: Bool?
        let enableInstallerLauncherService: Bool?
        let enableDownloaderService: Bool?
        let showReleaseNotes: Bool?
        let enableSystemProfiling: Bool?
        let sendProfileInfo: Bool?
        let enableJavaScript: Bool?
        let bundleName: String?               // SUBundleName

        var isEmpty: Bool {
            feedURL == nil && publicEDKey == nil && publicDSAKeyFile == nil
            && enableAutomaticChecks == nil && scheduledCheckInterval == nil
            && allowsAutomaticUpdates == nil && enableInstallerLauncherService == nil
            && enableDownloaderService == nil && showReleaseNotes == nil
            && enableSystemProfiling == nil && sendProfileInfo == nil
            && enableJavaScript == nil && bundleName == nil
        }
    }

    // B. AppleScript / Siri / Intents
    let appleScriptEnabled: Bool?            // NSAppleScriptEnabled
    let scriptingDefinition: String?         // OSAScriptingDefinition (.sdef)
    let userActivityTypes: [String]          // NSUserActivityTypes
    let intentsSupported: [String]           // INIntentsSupported (Siri)
    let safariExtensionCorrespondingIOSApp: String?  // SFSafariCorrespondingIOSAppBundleIdentifier

    // C. iCloud / Container
    let ubiquitousContainers: [[String: Any]]  // NSUbiquitousContainers

    // D. 通知
    let userNotificationAlertStyle: String?    // NSUserNotificationAlertStyle (none/badge/alert)
    let userNotificationsUsageDescription: String?
    let localNotificationUsageDescription: String?
    let remoteNotificationUsageDescription: String?

    // E. 杂项开发/生命周期开关
    let supportsSuddenTermination: Bool?
    let supportsAutomaticTermination: Bool?
    let lsRequiresCarbon: Bool?
    let lsRequiresNativeExecution: Bool?
    let lsMultipleInstancesProhibited: Bool?
    let lsHasLocalizedDisplayName: Bool?
    let lsFileQuarantineEnabled: Bool?
    let gpuEjectPolicy: String?
    let gpuSelectionPolicy: String?
    let itmsAppUsesNonExemptEncryption: Bool?  // ITSAppUsesNonExemptEncryption
}

enum ExtraInfoReader {
    static func read(from plist: [String: Any]) -> ExtraInfo {
        func str(_ key: String) -> String? {
            if let s = plist[key] as? String { return s }
            return plist[key].map { InfoPlistParser.describe($0) }
        }
        func bool(_ key: String) -> Bool? { plist[key] as? Bool }
        func int(_ key: String) -> Int? { plist[key] as? Int }
        func arr(_ key: String) -> [String] {
            (plist[key] as? [String])
                ?? (plist[key] as? [Any]).map { $0.map { InfoPlistParser.describe($0) } }
                ?? []
        }
        func dicts(_ key: String) -> [[String: Any]] {
            (plist[key] as? [[String: Any]])
                ?? (plist[key] as? [String: Any]).map { [$0] }
                ?? []
        }

        let sp = ExtraInfo.SparkleInfo(
            feedURL: str("SUFeedURL"),
            publicEDKey: str("SUPublicEDKey"),
            publicDSAKeyFile: str("SUPublicDSAKeyFile"),
            enableAutomaticChecks: bool("SUEnableAutomaticChecks"),
            scheduledCheckInterval: int("SUScheduledCheckInterval"),
            allowsAutomaticUpdates: bool("SUAllowsAutomaticUpdates"),
            enableInstallerLauncherService: bool("SUEnableInstallerLauncherService"),
            enableDownloaderService: bool("SUEnableDownloaderService"),
            showReleaseNotes: bool("SUShowReleaseNotes"),
            enableSystemProfiling: bool("SUEnableSystemProfiling"),
            sendProfileInfo: bool("SUSendProfileInfo"),
            enableJavaScript: bool("SUEnableJavaScript"),
            bundleName: str("SUBundleName")
        )

        return ExtraInfo(
            sparkle: sp.isEmpty ? nil : sp,
            appleScriptEnabled: bool("NSAppleScriptEnabled"),
            scriptingDefinition: str("OSAScriptingDefinition"),
            userActivityTypes: arr("NSUserActivityTypes"),
            intentsSupported: arr("INIntentsSupported"),
            safariExtensionCorrespondingIOSApp: str("SFSafariCorrespondingIOSAppBundleIdentifier"),
            ubiquitousContainers: dicts("NSUbiquitousContainers"),
            userNotificationAlertStyle: str("NSUserNotificationAlertStyle"),
            userNotificationsUsageDescription: str("NSUserNotificationsUsageDescription"),
            localNotificationUsageDescription: str("NSLocalNotificationUsageDescription"),
            remoteNotificationUsageDescription: str("NSRemoteNotificationUsageDescription"),
            supportsSuddenTermination: bool("NSSupportsSuddenTermination"),
            supportsAutomaticTermination: bool("NSSupportsAutomaticTermination"),
            lsRequiresCarbon: bool("LSRequiresCarbon"),
            lsRequiresNativeExecution: bool("LSRequiresNativeExecution"),
            lsMultipleInstancesProhibited: bool("LSMultipleInstancesProhibited"),
            lsHasLocalizedDisplayName: bool("LSHasLocalizedDisplayName"),
            lsFileQuarantineEnabled: bool("LSFileQuarantineEnabled"),
            gpuEjectPolicy: str("GPUEjectPolicy"),
            gpuSelectionPolicy: str("GPUSelectionPolicy"),
            itmsAppUsesNonExemptEncryption: bool("ITSAppUsesNonExemptEncryption")
        )
    }
}