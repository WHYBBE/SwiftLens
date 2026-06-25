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

    // F. 帮助 / 本地化 / Accent / Spotlight
    let helpBookName: String?                // CFBundleHelpBookName
    let helpBookFolder: String?              // CFBundleHelpBookFolder
    let bundleLocalizations: [String]        // CFBundleLocalizations
    let allowMixedLocalizations: Bool?       // CFBundleAllowMixedLocalizations
    let accentColorName: String?             // NSAccentColorName
    let mdItemKeywords: String?             // MDItemKeywords (Spotlight)

    // G. iOS 移植包字段
    let uIDeviceFamily: [Int]                // UIDeviceFamily (1=iPhone 2=iPad)
    let uiLaunchStoryboardName: String?
    let uiRequiresFullScreen: Bool?
    let uiSupportedInterfaceOrientations: [String]
    let uiStatusBarStyle: String?
    let uiBackgroundModes: [String]

    // H. Electron / 构建 / 厂商
    let electronTeamID: String?
    let sourceVersion: String?
    let requiredBuildHash: String?
    let scmRevision: String?
    let appIdentifierPrefix: String?
    let teamIdentifierPlist: String?         // Info.plist 内的 TeamIdentifier
    let bundleSpokenName: String?
    let vendorCode: String?
    let organizationIdentifier: String?
    let ctFontSuppressAutoDownload: Bool?
    let asWebAuthenticationSessionWebBrowserSupportCapabilities: Bool?

    // I. 网络 Bonjour
    let bonjourServices: [String]
}

enum ExtraInfoReader {
    static func read(from plist: [String: Any]) -> ExtraInfo {
        func str(_ key: String) -> String? {
            if let s = plist[key] as? String { return s }
            return plist[key].map { InfoPlistParser.describe($0) }
        }
        func bool(_ key: String) -> Bool? {
            if let b = plist[key] as? Bool { return b }
            if let n = plist[key] as? NSNumber { return n.boolValue }
            if let s = plist[key] as? String {
                if s == "true" || s == "YES" { return true }
                if s == "false" || s == "NO" { return false }
            }
            return nil
        }
        func int(_ key: String) -> Int? { plist[key] as? Int }
        func arr(_ key: String) -> [String] {
            let raw = plist[key]
            if let s = raw as? [String] { return s }
            if let a = raw as? [Any] { return a.map { InfoPlistParser.describe($0) } }
            return []
        }
        func ints(_ key: String) -> [Int] {
            if let a = plist[key] as? [Int] { return a }
            guard let arr = plist[key] as? [Any] else { return [] }
            return arr.compactMap { v -> Int? in
                if let n = v as? NSNumber { return n.intValue }
                if let s = v as? String, let i = Int(s) { return i }
                return nil
            }
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
            itmsAppUsesNonExemptEncryption: bool("ITSAppUsesNonExemptEncryption"),
            // F. 帮助 / 本地化 / Accent / Spotlight
            helpBookName: str("CFBundleHelpBookName"),
            helpBookFolder: str("CFBundleHelpBookFolder"),
            bundleLocalizations: arr("CFBundleLocalizations"),
            allowMixedLocalizations: bool("CFBundleAllowMixedLocalizations"),
            accentColorName: str("NSAccentColorName"),
            mdItemKeywords: str("MDItemKeywords"),
            // G. iOS 移植包
            uIDeviceFamily: ints("UIDeviceFamily"),
            uiLaunchStoryboardName: str("UILaunchStoryboardName"),
            uiRequiresFullScreen: bool("UIRequiresFullScreen"),
            uiSupportedInterfaceOrientations: arr("UISupportedInterfaceOrientations"),
            uiStatusBarStyle: str("UIStatusBarStyle"),
            uiBackgroundModes: arr("UIBackgroundModes"),
            // H. Electron / 构建 / 厂商
            electronTeamID: str("ElectronTeamID"),
            sourceVersion: str("SourceVersion"),
            requiredBuildHash: str("requiredBuildHash"),
            scmRevision: str("SCMRevision"),
            appIdentifierPrefix: str("AppIdentifierPrefix"),
            teamIdentifierPlist: str("TeamIdentifier"),
            bundleSpokenName: str("CFBundleSpokenName"),
            vendorCode: str("VendorCode"),
            organizationIdentifier: str("OrganizationIdentifier"),
            ctFontSuppressAutoDownload: bool("CTFontSuppressAutoDownload"),
            asWebAuthenticationSessionWebBrowserSupportCapabilities: bool("ASWebAuthenticationSessionWebBrowserSupportCapabilities"),
            // I. Bonjour
            bonjourServices: arr("NSBonjourServices")
        )
    }
}