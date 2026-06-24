import SwiftUI
import AppKit

/// 详情面板：以分区形式展示 .app 信息。
struct DetailView: View {
    let info: AppInfo

    // 本地状态：用户点击「移除隔离」后即时刷新本区块，
    // 无需重新跑 AppInfoLoader 即可反映结果。
    @State private var quarantineRemoved: Bool = false
    @State private var removeError: String?

    /// 顶部状态对应的目标位置锚点。
    enum DetailAnchor: Hashable {
        case architectures
        case quarantine
        case codeSign
        case privacy
        case ats
        case subBundles
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection(proxy: proxy)
                    basicSection
                    runtimeSection
                    architecturesSection
                        .id(DetailAnchor.architectures)
                    documentTypesSection
                    urlSchemesSection
                    privacySection
                        .id(DetailAnchor.privacy)
                    atsSection
                        .id(DetailAnchor.ats)
                    quarantineSection
                        .id(DetailAnchor.quarantine)
                    xattrsSection
                    codeSignSection
                        .id(DetailAnchor.codeSign)
                    entitlementsSection
                    subBundlesSection
                        .id(DetailAnchor.subBundles)
                    fileSection
                    rawPlistSection
                    rawCodesignSection
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(info.bundleURL.lastPathComponent)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([info.bundleURL])
                    } label: { Label("在访达中显示", systemImage: "folder") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        copyToPasteboard(summaryString())
                    } label: { Label("复制摘要", systemImage: "doc.on.doc") }
                }
            }
        }
    }

    // MARK: 顶部头
    private func headerSection(proxy: ScrollViewProxy) -> some View {
        HStack(alignment: .top, spacing: 16) {
            if let icon = info.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 72, height: 72)
            } else {
                Image(systemName: "app")
                    .resizable()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(info.displayName ?? info.bundleName ?? info.bundleURL.lastPathComponent)
                    .font(.system(.title2, design: .default).bold())
                if let bid = info.bundleIdentifier {
                    Text(bid).font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                Text(info.bundleURL.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                // 顺序与下方分区一致：架构 → 隔离 → 代码签名
                Button {
                    withAnimation { proxy.scrollTo(DetailAnchor.architectures, anchor: .top) }
                } label: {
                    let archLabel = info.architectures.isEmpty
                        ? "未知架构"
                        : (info.architectures.count > 1
                            ? "Universal (\(info.architectures.count) 切片)"
                            : info.architectures.first!.name)
                    Badge(text: archLabel, color: .blue)
                }
                .buttonStyle(.plain)
                .help("跳转到「架构」分区")

                Button {
                    withAnimation { proxy.scrollTo(DetailAnchor.quarantine, anchor: .top) }
                } label: {
                    Badge(text: info.quarantine != nil ? "已隔离" : "无隔离",
                          color: info.quarantine != nil ? .yellow : .gray)
                }
                .buttonStyle(.plain)
                .help("跳转到「Quarantine」分区")

                // 签名状态 + 有效性 + 公证，同一行，三个都跳转到代码签名分区
                HStack(spacing: 6) {
                    Button {
                        withAnimation { proxy.scrollTo(DetailAnchor.codeSign, anchor: .top) }
                    } label: {
                        Badge(text: info.codeSign.state.rawValue,
                              color: badgeColor(for: info.codeSign.state))
                    }
                    .buttonStyle(.plain)
                    .help("跳转到「代码签名」分区")

                    Button {
                        withAnimation { proxy.scrollTo(DetailAnchor.codeSign, anchor: .top) }
                    } label: {
                        Badge(text: info.codeSign.validity.rawValue,
                              color: validityColor(info.codeSign.validity))
                    }
                    .buttonStyle(.plain)
                    .help("跳转到「代码签名」分区")

                    Button {
                        withAnimation { proxy.scrollTo(DetailAnchor.codeSign, anchor: .top) }
                    } label: {
                        Badge(text: info.codeSign.notarization.rawValue,
                              color: notarizationColor(info.codeSign.notarization))
                    }
                    .buttonStyle(.plain)
                    .help("跳转到「代码签名」分区")
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.3)))
    }

    // MARK: 基本信息
    private var basicSection: some View {
        SectionView("基本信息") {
            RowView(key: "CFBundleDisplayName", value: info.displayName ?? "—")
            RowView(key: "CFBundleName", value: info.bundleName ?? "—")
            RowView(key: "CFBundleIdentifier", value: info.bundleIdentifier ?? "—")
            RowView(key: "CFBundleShortVersionString", value: info.bundleShortVersion ?? "—")
            RowView(key: "CFBundleVersion", value: info.bundleVersion ?? "—")
            if let v = info.longVersionString { RowView(key: "CFBundleLongVersionString", value: v) }
            if let v = info.getInfoString { RowView(key: "CFBundleGetInfoString", value: v) }
            if let v = info.bundleSignature { RowView(key: "CFBundleSignature", value: v) }
            RowView(key: "CFBundleExecutable", value: info.executableName ?? "—")
            RowView(key: "可执行文件路径", value: info.executablePath ?? "—")
            RowView(key: "CFBundlePackageType", value: info.bundlePackageType ?? "—")
            RowView(key: "CFBundleInfoDictionaryVersion", value: info.infoDictionaryVersion ?? "—")
            RowView(key: "CFBundleDevelopmentRegion", value: info.developmentRegion ?? "—")
            if let v = info.principalClass { RowView(key: "NSPrincipalClass", value: v) }
            if let v = info.humanReadableCopyright { RowView(key: "NSHumanReadableCopyright", value: v) }
            if !info.supportedPlatforms.isEmpty {
                RowView(key: "CFBundleSupportedPlatforms", value: info.supportedPlatforms.joined(separator: ", "))
            }
        }
    }

    // MARK: 运行时 / 部署
    private var runtimeSection: some View {
        SectionView("运行环境 & 部署") {
            RowView(key: "LSMinimumSystemVersion", value: info.minimumOSVersion ?? "—")
            RowView(key: "LSApplicationCategoryType", value: info.applicationCategoryType ?? "—")
            RowView(key: "LSRequiresAquaSystemAppearance", value: bool(info.requiresAquaSystemAppearance))
            RowView(key: "NSHighResolutionCapable", value: bool(info.highResolutionCapable))
            RowView(key: "NSSupportsHighResolutionDisplays", value: bool(info.supportsHighResolutionDisplays))
            RowView(key: "NSCanAnimateAlpha", value: bool(info.canAnimateAlpha))
            RowView(key: "NSSupportsAutomaticGraphicsSwitching", value: bool(info.supportsAutomaticGraphicsSwitching))
            RowView(key: "NSQuitAlwaysKeepsWindows", value: bool(info.quitAlwaysKeepsWindows))
            RowView(key: "NSPrefersDisplaySafeAreaCompatibilityMode", value: bool(info.prefersDisplaySafeAreaCompatibilityMode))
            RowView(key: "LSBackgroundOnly", value: bool(info.requiresBackgroundGesture))
            RowView(key: "CSResourcesFileMapped", value: bool(info.csResourcesFileMapped))
            RowView(key: "CFBundleUses24HourClock", value: bool(info.uses24HourClock))
            if !info.lsEnvironment.isEmpty {
                Divider().padding(.vertical, 2)
                Text("LSEnvironment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(info.lsEnvironment.keys.sorted(), id: \.self) { k in
                    RowView(key: k, value: info.lsEnvironment[k] ?? "—")
                }
            }
            Divider().padding(.vertical, 2)
            Text("构建工具链")
                .font(.caption)
                .foregroundStyle(.secondary)
            RowView(key: "DTSDKName", value: info.sdkVersion ?? "—")
            RowView(key: "DTPlatformName", value: info.platformName ?? "—")
            RowView(key: "DTPlatformVersion", value: info.platformVersion ?? "—")
            RowView(key: "DTSDKBuild", value: info.sdkBuild ?? "—")
            RowView(key: "DTPlatformBuild", value: info.platformBuild ?? "—")
            RowView(key: "DTXcode", value: info.xcodeVersion ?? "—")
            RowView(key: "DTXcodeBuild", value: info.xcodeBuild ?? "—")
            RowView(key: "DTCompiler", value: info.dtCompiler ?? "—")
            RowView(key: "BuildMachineOSBuild", value: info.buildMachineOSBuild ?? "—")
        }
    }

    // MARK: 架构
    private var architecturesSection: some View {
        SectionView("架构 (Mach-O)",
                    subtitle: "通用二进制切片") {
            if info.architectures.isEmpty {
                PlaceholderRow(text: "未找到可执行文件或无法解析 Intel 切片")
            } else {
                ForEach(Array(info.architectures.enumerated()), id: \.offset) { _, arch in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(arch.name).font(.system(.body, design: .monospaced).bold())
                            Text("· \(arch.cpuType) · \(arch.bits)-bit")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        RowView(key: "切片大小", value: formattedSize(arch.fileSize))
                        RowView(key: "在 Fat 中偏移", value: arch.offsetInFat == 0 ? "—(非 Fat)" : "0x\(String(arch.offsetInFat, radix: 16))")
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: 文档类型
    private var documentTypesSection: some View {
        SectionView("文档类型 (CFBundleDocumentTypes)", subtitle: "\(info.documentTypes.count) 项") {
            if info.documentTypes.isEmpty {
                PlaceholderRow(text: "未声明自定义文档类型")
            } else {
                ForEach(Array(info.documentTypes.enumerated()), id: \.offset) { i, doc in
                    VStack(alignment: .leading, spacing: 4) {
                        RowView(key: "名称", value: (doc["CFBundleTypeName"] as? String) ?? "—")
                        RowView(key: "角色", value: (doc["CFBundleTypeRole"] as? String) ?? "—")
                        RowView(key: "图标", value: (doc["CFBundleTypeIconFile"] as? String) ?? "—")
                        RowView(key: "LSItemContentTypes",
                                value: (doc["LSItemContentTypes"] as? [String] ?? []).joined(separator: ", "))
                        RowView(key: "LSHandlerRank", value: (doc["LSHandlerRank"] as? String) ?? "—")
                    }
                    .padding(.vertical, 4)
                    if i < info.documentTypes.count - 1 { Divider() }
                }
            }
            if !info.exportedTypeIdentifiers.isEmpty || !info.importedTypeIdentifiers.isEmpty {
                Divider().padding(.vertical, 4)
                RowView(key: "Exported UTIs", value: "\(info.exportedTypeIdentifiers.count)")
                RowView(key: "Imported UTIs", value: "\(info.importedTypeIdentifiers.count)")
            }
            if !info.services.isEmpty {
                RowView(key: "NSServices", value: "\(info.services.count) 项")
            }
        }
    }

    // MARK: URL Schemes
    private var urlSchemesSection: some View {
        SectionView("URL Schemes", subtitle: "\(info.urlSchemes.count) 项") {
            if info.urlSchemes.isEmpty {
                PlaceholderRow(text: "未声明 URL Scheme")
            } else {
                ForEach(info.urlSchemes, id: \.self) { scheme in
                    RowView(key: scheme, value: "\(scheme)://")
                }
            }
        }
    }

    // MARK: 隐私 / TCC 权限描述
    private var privacySection: some View {
        SectionView(
            "隐私权限描述 (TCC Usage Descriptions)",
            subtitle: "\(info.privacyEntries.count) 项"
        ) {
            if info.privacyEntries.isEmpty {
                PlaceholderRow(text: "未声明任何 NS***UsageDescription 权限描述")
            } else {
                ForEach(info.privacyEntries) { e in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: e.systemImage)
                                .font(.title3)
                                .foregroundStyle(.tint)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.displayTitle).font(.body.bold())
                                Text(e.key)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        if !e.description.isEmpty {
                            Text(e.description)
                                .font(.system(.callout, design: .default))
                                .foregroundStyle(.primary)
                                .padding(.leading, 32)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.3)))
                }
            }
        }
    }

    // MARK: 网络安全 ATS · Electron
    private var atsSection: some View {
        let ats = info.appTransportSecurity
        let asar = info.electronAsarIntegrity
        return SectionView(
            "网络安全 / ATS · Electron",
            subtitle: (ats == nil && asar == nil) ? "无" :
                [ats != nil ? "ATS" : nil, asar != nil ? "Asar" : nil]
                    .compactMap { $0 }.joined(separator: ", ")
        ) {
            if let ats = ats {
                Text("NSAppTransportSecurity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(InfoPlistParser.flatten(ats).sorted { $0.0 < $1.0 }, id: \.0) { row in
                    RowView(key: row.0, value: row.1)
                }
            }
            if let asar = asar {
                if ats != nil { Divider().padding(.vertical, 4) }
                Text("ElectronAsarIntegrity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(InfoPlistParser.flatten(asar).sorted { $0.0 < $1.0 }, id: \.0) { row in
                    RowView(key: row.0, value: row.1)
                }
            }
            if ats == nil && asar == nil {
                PlaceholderRow(text: "未声明 NSAppTransportSecurity / ElectronAsarIntegrity")
            }
        }
    }

    // MARK: 扩展属性全列表
    private var xattrsSection: some View {
        SectionView(
            "扩展属性 (xattrs)",
            subtitle: "\(info.extendedXattrs.names.count) 项"
        ) {
            if info.extendedXattrs.names.isEmpty {
                PlaceholderRow(text: "无任何扩展属性")
            } else {
                ForEach(info.extendedXattrs.names, id: \.self) { name in
                    RowView(
                        key: name,
                        value: info.extendedXattrs.descriptions[name] ?? "<空>"
                    )
                }
            }
        }
    }

    // MARK: Quarantine
    private var quarantineSection: some View {
        let q = quarantineRemoved ? nil : info.quarantine
        return SectionView(
            "Quarantine 隔离标记",
            subtitle: q == nil ? "无" : "已隔离"
        ) {
            if let q = q {
                RowView(key: "原始值", value: q.raw)
                RowView(key: "Flags", value: q.flags)
                RowView(key: "下载 Agent", value: q.agent.isEmpty ? "—" : q.agent)
                RowView(key: "时间戳(十六进制)", value: q.timestampString)
                if let d = q.downloadDate {
                    RowView(key: "下载时间", value: iso(d))
                }

                Divider().padding(.vertical, 4)

                HStack {
                    Button(role: .destructive) {
                        let err = QuarantineReader.remove(for: info.bundleURL)
                        if let err = err {
                            removeError = "移除失败: \(err)"
                        } else {
                            quarantineRemoved = true
                            removeError = nil
                        }
                    } label: {
                        Label("移除 Quarantine 隔离标记", systemImage: "xmark.shield")
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    if info.codeSign.state == .adhoc || info.codeSign.state == .unsigned {
                        Text("提示：ad-hoc / 未签名应用移除隔离后可绕过 Gatekeeper，请自行确认来源可信。")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .frame(width: 320, alignment: .trailing)
                    }
                }
                if let err = removeError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            } else {
                PlaceholderRow(text: quarantineRemoved
                                ? "已成功移除 com.apple.quarantine (本进程内即时生效)"
                                : "未检测到 com.apple.quarantine 扩展属性 (可信来源 / 已清隔离)")
            }
        }
    }

    // MARK: 代码签名
    private var codeSignSection: some View {
        let cs = info.codeSign
        return SectionView("代码签名 (Code Signing)") {
            RowView(key: "签名状态", value: cs.state.rawValue)
            RowView(key: "有效性", value: cs.validity.rawValue)
            RowView(key: "公证 (Notarization)", value: cs.notarization.rawValue)
            if let v = cs.format { RowView(key: "Format", value: v) }
            if let v = cs.identifier { RowView(key: "Identifier", value: v) }
            if let v = cs.teamIdentifier { RowView(key: "TeamIdentifier", value: v) }
            if let v = cs.signatureType { RowView(key: "Signature", value: v) }
            if let v = cs.runtimeVersion { RowView(key: "Runtime Version", value: v) }

            if let v = cs.codeDirectoryVersion {
                RowView(key: "CodeDirectory v", value: v)
            }
            if let v = cs.codeDirectorySize { RowView(key: "CodeDirectory size", value: v) }
            if let v = cs.codeDirectoryHashes { RowView(key: "CodeDirectory hashes", value: v) }
            if let v = cs.flags { RowView(key: "flags (原始)", value: v) }
            if !cs.decodedFlags.isEmpty {
                RowView(key: "flags (解码)", value: cs.decodedFlags.joined(separator: ", "))
            }

            if let v = cs.cdHash { RowView(key: "CDHash", value: v) }
            if let v = cs.candidateCDHash { RowView(key: "CandidateCDHash", value: v) }
            if let v = cs.candidateCDHashFull { RowView(key: "CandidateCDHashFull", value: v) }
            if let v = cs.hashType { RowView(key: "Hash type", value: v) }
            if let v = cs.hashChoices { RowView(key: "Hash choices", value: v) }
            if let v = cs.cmsDigest { RowView(key: "CMSDigest", value: v) }
            if let v = cs.cmsDigestType { RowView(key: "CMSDigestType", value: v) }

            if let v = cs.sealedResourcesVersion {
                RowView(key: "Sealed Resources version", value: v)
            }
            if let v = cs.sealedResourcesRules { RowView(key: "Sealed rules", value: v) }
            if let v = cs.sealedResourcesFiles { RowView(key: "Sealed files", value: v) }
            if let v = cs.internalRequirements { RowView(key: "Internal requirements", value: v) }
            if let v = cs.infoPlistEntries { RowView(key: "Info.plist entries", value: v) }
            if let v = cs.totalSignatures { RowView(key: "Total signatures", value: v) }
            if let v = cs.chosenSignature { RowView(key: "Chosen signature", value: v) }

            if !cs.authorities.isEmpty {
                Divider().padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Authority 链")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(cs.authorities, id: \.self) { a in
                        RowView(key: "• ", value: a)
                    }
                }
            }
        }
    }

    // MARK: Entitlements
    private var entitlementsSection: some View {
        let cs = info.codeSign
        return SectionView("Entitlements 权限",
                           subtitle: cs.entitlements == nil ? "无" : "\(cs.entitlements!.count) 项") {
            if let ent = cs.entitlements, !ent.isEmpty {
                ForEach(InfoPlistParser.flatten(ent).sorted { $0.0 < $1.0 }, id: \.0) { row in
                    RowView(key: row.0, value: row.1)
                }
            } else if let raw = cs.entitlementsRaw {
                DisclosureGroup("原始 XML") {
                    ScrollView(.horizontal) {
                        Text(raw)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 220)
                }
            } else {
                PlaceholderRow(text: "无 entitlements (未签名 / 无沙盒)")
            }
        }
    }

    // MARK: 文件信息
    private var fileSection: some View {
        SectionView("文件信息") {
            RowView(key: "完整路径", value: info.bundleURL.path)
            RowView(key: "总大小", value: "\(info.formattedFileSize()) (\(info.fileSize) 字节)")
            RowView(key: "修改时间", value: info.modificationDate.map { iso($0) } ?? "—")
            RowView(key: "创建时间", value: info.creationDate.map { iso($0) } ?? "—")
            RowView(key: "权限 (octal)", value: info.permissions ?? "—")
        }
    }

    // MARK: 子 bundle (Frameworks / Helpers / XPC / PlugIns)
    private var subBundlesSection: some View {
        SectionView(
            "内嵌子 bundle",
            subtitle: "\(info.subBundles.count) 项 · \(formattedSize(info.subBundlesTotalSize))"
        ) {
            if info.subBundles.isEmpty {
                PlaceholderRow(text: "未发现内嵌 Framework / Helper / XPC / PlugIns / LoginItems")
            } else {
                ForEach(Array(info.subBundles.enumerated()), id: \.element.id) { i, sub in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: subBundleIcon(for: sub.kind))
                                .foregroundStyle(.tint)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(sub.relativePath)
                                    .font(.system(.body, design: .monospaced).bold())
                                if let bid = sub.bundleIdentifier {
                                    Text(bid)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Badge(text: sub.signatureState.rawValue,
                                  color: badgeColor(for: sub.signatureState))
                        }
                        if let ver = sub.bundleVersion {
                            RowView(key: "版本", value: ver)
                        }
                        if let exec = sub.executableName {
                            RowView(key: "CFBundleExecutable", value: exec)
                        }
                        if let sig = sub.signatureType {
                            RowView(key: "Signature", value: sig)
                        }
                        if let runtime = sub.runtimeVersion {
                            RowView(key: "Runtime Version", value: runtime)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.3)))
                    if i < info.subBundles.count - 1 { Spacer().frame(height: 4) }
                }
            }
        }
    }

    // MARK: 原始 Info.plist
    private var rawPlistSection: some View {
        SectionView("Info.plist 完整内容",
                    subtitle: "\(info.flatRows.count) 项键") {
            DisclosureGroup("展开 Info.plist 全部键值") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(info.flatRows, id: \.0) { row in
                            RowView(key: row.0, value: row.1)
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
        }
    }

    // MARK: codesign 原始输出
    private var rawCodesignSection: some View {
        SectionView("codesign 原始输出") {
            DisclosureGroup("展开 codesign -dvvv 输出") {
                ScrollView {
                    Text(info.codeSign.detailRaw.isEmpty ? "(无)" : info.codeSign.detailRaw)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 280)
            }
        }
    }

    // MARK: helpers
    private func bool(_ v: Bool?) -> String {
        switch v {
        case .some(true): return "YES"
        case .some(false): return "NO"
        case .none:        return "—"
        }
    }

    private func iso(_ d: Date) -> String {
        ISO8601DateFormatter().string(from: d)
    }

    private func formattedSize(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func badgeColor(for s: CodeSignInfo.SignedState) -> Color {
        switch s {
        case .signed:  return .green
        case .adhoc:   return .orange
        case .unsigned: return .red
        case .unknown: return .gray
        }
    }

    private func validityColor(_ v: CodeSignInfo.Validity) -> Color {
        switch v {
        case .valid: return .green
        case .invalid: return .red
        case .untested: return .gray
        }
    }

    private func notarizationColor(_ n: CodeSignInfo.Notarization) -> Color {
        switch n {
        case .notarized:    return .green
        case .notNotarized: return .gray
        case .unknown:      return .gray
        }
    }

    private func subBundleIcon(for kind: SubBundle.Kind) -> String {
        switch kind {
        case .framework: return "shippingbox"
        case .app:       return "app.gift"
        case .xpc:       return "antenna.radiowaves.left.and.right"
        case .kext:      return "externaldrive"
        case .plugin:    return "puzzlepiece.extension"
        case .loginItem: return "power"
        case .other:     return "shippingbox.fill"
        }
    }

    private func summaryString() -> String {
        var lines: [String] = []
        lines.append("# \(info.displayName ?? info.bundleName ?? info.bundleURL.lastPathComponent)")
        lines.append("路径: \(info.bundleURL.path)")
        lines.append("BundleID: \(info.bundleIdentifier ?? "—")")
        lines.append("版本: \(info.bundleShortVersion ?? "—") (\(info.bundleVersion ?? "—"))")
        lines.append("最低系统版本: \(info.minimumOSVersion ?? "—")")
        let archs = info.architectures.map { $0.name }.joined(separator: ", ")
        lines.append("架构: \(archs.isEmpty ? "—" : archs)")
        if !info.supportedPlatforms.isEmpty {
            lines.append("支持平台: \(info.supportedPlatforms.joined(separator: ", "))")
        }
        if let v = info.principalClass { lines.append("NSPrincipalClass: \(v)") }
        if let v = info.humanReadableCopyright { lines.append("版权: \(v)") }
        let cs = info.codeSign
        lines.append("签名: \(cs.state.rawValue) — \(cs.validity.rawValue) — \(cs.notarization.rawValue)")
        if let v = cs.format { lines.append("Format: \(v)") }
        if let id = cs.identifier { lines.append("Identifier: \(id)") }
        if let team = cs.teamIdentifier { lines.append("TeamIdentifier: \(team)") }
        if let cdh = cs.cdHash { lines.append("CDHash: \(cdh)") }
        if !cs.decodedFlags.isEmpty { lines.append("签名 flags: \(cs.decodedFlags.joined(separator: ", "))") }
        if let v = cs.runtimeVersion { lines.append("Runtime Version: \(v)") }
        if !cs.authorities.isEmpty {
            lines.append("Authority:")
            cs.authorities.forEach { lines.append("  - \($0)") }
        }
        lines.append("隐私权限描述: \(info.privacyEntries.count) 项")
        if !info.privacyEntries.isEmpty {
            for e in info.privacyEntries.prefix(10) {
                lines.append("  · \(e.displayTitle) [\(e.key)]: \(e.description)")
            }
            if info.privacyEntries.count > 10 {
                lines.append("  ... 另外 \(info.privacyEntries.count - 10) 项")
            }
        }
        if info.appTransportSecurity != nil { lines.append("ATS: 已声明 NSAppTransportSecurity") }
        if info.electronAsarIntegrity != nil { lines.append("Electron: 已声明 ElectronAsarIntegrity") }
        if let q = info.quarantine { lines.append("Quarantine: flags=\(q.flags) agent=\(q.agent) 时间=\(q.timestampString)") }
        else { lines.append("Quarantine: 无") }
        if !info.extendedXattrs.names.isEmpty {
            lines.append("扩展属性: \(info.extendedXattrs.names.joined(separator: ", "))")
        }
        lines.append("子 bundle: \(info.subBundles.count) 项 (\(formattedSize(info.subBundlesTotalSize)))")
        if !info.subBundles.isEmpty {
            for sub in info.subBundles.prefix(10) {
                lines.append("  · [\(sub.kind.rawValue)] \(sub.relativePath) — \(sub.bundleIdentifier ?? "—")")
            }
            if info.subBundles.count > 10 {
                lines.append("  ... 另外 \(info.subBundles.count - 10) 项")
            }
        }
        lines.append("文件大小: \(info.formattedFileSize()) (\(info.fileSize) 字节)")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Badge
struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.25)))
            .overlay(Capsule().stroke(color.opacity(0.6), lineWidth: 1))
            .foregroundStyle(color)
    }
}