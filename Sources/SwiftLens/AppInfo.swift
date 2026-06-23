import Foundation
import AppKit

// MARK: - AppInfo 模型

/// 收集一个 .app bundle 的完整信息。
struct AppInfo {
    let bundleURL: URL

    // 基本信息
    let displayName: String?
    let bundleName: String?
    let bundleIdentifier: String?
    let bundleShortVersion: String?     // CFBundleShortVersionString
    let bundleVersion: String?          // CFBundleVersion
    let executableName: String?
    let executablePath: String?
    let bundlePackageType: String?
    let infoDictionaryVersion: String?
    let developmentRegion: String?

    // 运行环境
    let minimumOSVersion: String?
    let lsMinimumSystemVersion: String?
    let applicationCategoryType: String?
    let requiresAquaSystemAppearance: Bool?
    let highResolutionCapable: Bool?
    let canAnimateAlpha: Bool?
    let supportsHighResolutionDisplays: Bool?
    let requiresBackgroundGesture: Bool?
    let uses24HourClock: Bool?

    // 链接 / 部署
    let sdkVersion: String?   // DTSDKName / DTSDKName + DTPlatformName + DTSDKBuild
    let platformName: String?
    let sdkBuild: String?
    let platformBuild: String?
    let xcodeBuild: String?

    // 文档 / URL
    let documentTypes: [[String: Any]]
    let urlSchemes: [String]
    let exportedTypeIdentifiers: [[String: Any]]
    let importedTypeIdentifiers: [[String: Any]]
    let services: [[String: Any]]

    // 权限 / 沙盒
    let hasDockIcon: Bool?
    let documentControllerEnabled: Bool?

    // 文件系统
    let fileSize: UInt64
    let modificationDate: Date?
    let creationDate: Date?
    let permissions: String?

    // Info.plist 全部键值
    let rawInfoPlist: [String: Any]
    let flatRows: [(String, String)]

    // 扩展属性 / 隔离
    let quarantine: QuarantineInfo?

    // 代码签名
    let codeSign: CodeSignInfo

    // 架构
    let architectures: [ArchitectureReader.ArchInfo]

    // 图标
    let icon: NSImage?
}

enum AppInfoLoader {

    static func load(url: URL) -> AppInfo {
        let rawPlist = InfoPlistParser.parse(at: url) ?? [:]
        let rows = InfoPlistParser.flatten(rawPlist)

        func str(_ key: String) -> String? {
            if let v = rawPlist[key] as? String { return v }
            return rawPlist[key].map { InfoPlistParser.describe($0) }
        }
        func dict(_ key: String) -> [[String: Any]] {
            (rawPlist[key] as? [[String: Any]]) ?? (rawPlist[key] as? [String: Any]).map { [$0] } ?? []
        }

        let execName = str("CFBundleExecutable")
        let execPath: String?
        if let name = execName {
            execPath = url.appendingPathComponent("Contents/MacOS/\(name)").path
        } else {
            execPath = nil
        }

        // 文件系统属性
        var fileSize: UInt64 = 0
        var modDate: Date?
        var creationDate: Date?
        var perms: String?
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            modDate = attrs[.modificationDate] as? Date
            creationDate = attrs[.creationDate] as? Date
            if let posix = attrs[.posixPermissions] as? NSNumber {
                perms = String(format: "%o", posix.intValue)
            }
        }
        // bundle 是目录，体积需递归累加
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: []) {
            for case let fileURL as URL in enumerator {
                if let v = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let s = v.fileSize {
                    fileSize += UInt64(s)
                }
            }
        }

        // URL Schemes
        var schemes: [String] = []
        for cf in dict("CFBundleURLTypes") {
            if let s = cf["CFBundleURLSchemes"] as? [String] {
                schemes.append(contentsOf: s)
            }
        }

        // 图标
        var icon: NSImage?
        let iconURL = url.appendingPathComponent("Contents/Resources/\(str("CFBundleIconFile") ?? "AppIcon")")
        if FileManager.default.fileExists(atPath: iconURL.path) {
            icon = NSImage(contentsOf: iconURL)
        } else {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        }

        return AppInfo(
            bundleURL: url,
            displayName: str("CFBundleDisplayName"),
            bundleName: str("CFBundleName"),
            bundleIdentifier: str("CFBundleIdentifier"),
            bundleShortVersion: str("CFBundleShortVersionString"),
            bundleVersion: str("CFBundleVersion"),
            executableName: execName,
            executablePath: execPath,
            bundlePackageType: str("CFBundlePackageType"),
            infoDictionaryVersion: str("CFBundleInfoDictionaryVersion"),
            developmentRegion: str("CFBundleDevelopmentRegion"),
            minimumOSVersion: str("LSMinimumSystemVersion"),
            lsMinimumSystemVersion: str("LSMinimumSystemVersion"),
            applicationCategoryType: str("LSApplicationCategoryType"),
            requiresAquaSystemAppearance: (rawPlist["LSRequiresAquaSystemAppearance"] as? Bool),
            highResolutionCapable: (rawPlist["NSHighResolutionCapable"] as? Bool),
            canAnimateAlpha: (rawPlist["NSCanAnimateAlpha"] as? Bool),
            supportsHighResolutionDisplays: (rawPlist["NSSupportsHighResolutionDisplays"] as? Bool),
            requiresBackgroundGesture: (rawPlist["LSBackgroundOnly"] as? Bool),
            uses24HourClock: (rawPlist["CFBundleUses24HourClock"] as? Bool),
            sdkVersion: str("DTSDKName"),
            platformName: str("DTPlatformName"),
            sdkBuild: str("DTSDKBuild"),
            platformBuild: str("DTPlatformBuild"),
            xcodeBuild: str("DTXcodeBuild"),
            documentTypes: dict("CFBundleDocumentTypes"),
            urlSchemes: schemes,
            exportedTypeIdentifiers: dict("UTExportedTypeDeclarations"),
            importedTypeIdentifiers: dict("UTImportedTypeDeclarations"),
            services: dict("NSServices"),
            hasDockIcon: (rawPlist["LSUIElement"] as? Bool) == false ? true : nil,
            documentControllerEnabled: (rawPlist["NSMainNibFile"] != nil),
            fileSize: fileSize,
            modificationDate: modDate,
            creationDate: creationDate,
            permissions: perms,
            rawInfoPlist: rawPlist,
            flatRows: rows,
            quarantine: QuarantineReader.read(for: url),
            codeSign: CodeSignReader.read(for: url),
            architectures: ArchitectureReader.read(for: url),
            icon: icon
        )
    }
}

// MARK: - 格式化辅助
extension AppInfo {
    func formattedFileSize() -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}