import Foundation
import Security

// MARK: - 代码签名信息

struct CodeSignInfo {
    enum SignedState: String {
        case signed       = "已签名 (Signed)"
        case adhoc        = "Ad-hoc 签名"
        case unsigned     = "未签名 (Not signed)"
        case unknown      = "未知"
    }
    enum Validity: String {
        case valid    = "通过 (Valid)"
        case invalid  = "无效 (Invalid)"
        case untested = "未验证"
    }
    enum Notarization: String {
        case notarized      = "已公证 (Notarized)"
        case notNotarized   = "未公证"
        case unknown        = "未知"
    }

    let state: SignedState
    let validity: Validity
    let notarization: Notarization

    let detailRaw: String          // codesign -dvvv 完整输出
    let identifier: String?
    let teamIdentifier: String?
    let authorities: [String]
    let cdHash: String?
    let candidateCDHash: String?
    let candidateCDHashFull: String?
    let hashType: String?
    let hashChoices: String?
    let signatureType: String?     // "adhoc" / "valid" / ...
    let flags: String?             // 原始 flags 字符串
    let decodedFlags: [String]     // 解码后的标志列表
    let codeDirectoryVersion: String?
    let codeDirectorySize: String?
    let codeDirectoryHashes: String?
    let format: String?
    let runtimeVersion: String?
    let sealedResourcesVersion: String?
    let sealedResourcesRules: String?
    let sealedResourcesFiles: String?
    let internalRequirements: String?
    let cmsDigest: String?
    let cmsDigestType: String?
    let totalSignatures: String?
    let chosenSignature: String?
    let infoPlistEntries: String?

    let entitlementsRaw: String?   // entitlements 原始 XML plist
    let entitlements: [String: Any]?
    let error: String?
}

enum CodeSignReader {

    static func read(for bundleURL: URL) -> CodeSignInfo {
        var identifier: String?
        var teamIdentifier: String?
        var authorities: [String] = []
        var cdHash: String?
        var candidateCDHash: String?
        var candidateCDHashFull: String?
        var hashType: String?
        var hashChoices: String?
        var signatureType: String?
        var flags: String?
        var decodedFlags: [String] = []
        var codeDirectoryVersion: String?
        var codeDirectorySize: String?
        var codeDirectoryHashes: String?
        var format: String?
        var runtimeVersion: String?
        var sealedResourcesVersion: String?
        var sealedResourcesRules: String?
        var sealedResourcesFiles: String?
        var internalRequirements: String?
        var cmsDigest: String?
        var cmsDigestType: String?
        var totalSignatures: String?
        var chosenSignature: String?
        var infoPlistEntries: String?
        var error: String?

        let dvvv = runCodesign(args: ["-dvvv", bundleURL.path])
        if dvvv.failed {
            error = dvvv.error
            if dvvv.error.contains("not signed at all") {
                return CodeSignInfo(
                    state: .unsigned, validity: .untested,
                    notarization: .unknown,
                    detailRaw: dvvv.error,
                    identifier: nil, teamIdentifier: nil, authorities: [], cdHash: nil,
                    candidateCDHash: nil, candidateCDHashFull: nil,
                    hashType: nil, hashChoices: nil, signatureType: nil,
                    flags: nil, decodedFlags: [],
                    codeDirectoryVersion: nil, codeDirectorySize: nil, codeDirectoryHashes: nil,
                    format: nil, runtimeVersion: nil,
                    sealedResourcesVersion: nil, sealedResourcesRules: nil, sealedResourcesFiles: nil,
                    internalRequirements: nil, cmsDigest: nil, cmsDigestType: nil,
                    totalSignatures: nil, chosenSignature: nil, infoPlistEntries: nil,
                    entitlementsRaw: nil, entitlements: nil, error: error
                )
            }
        }

        // 解析大端文本字段
        for line in dvvv.output.split(separator: "\n") {
            let s = String(line)
            if s.hasPrefix("Identifier=") {
                identifier = String(s.dropFirst("Identifier=".count))
            } else if s.hasPrefix("TeamIdentifier=") {
                teamIdentifier = String(s.dropFirst("TeamIdentifier=".count))
            } else if s.hasPrefix("Authority=") {
                authorities.append(String(s.dropFirst("Authority=".count)))
            } else if s.hasPrefix("CDHash=") {
                cdHash = String(s.dropFirst("CDHash=".count))
            } else if s.hasPrefix("CandidateCDHash sha256=") {
                candidateCDHash = String(s.dropFirst("CandidateCDHash sha256=".count))
            } else if s.hasPrefix("CandidateCDHashFull sha256=") {
                candidateCDHashFull = String(s.dropFirst("CandidateCDHashFull sha256=".count))
            } else if s.hasPrefix("Hash type=") {
                hashType = String(s.dropFirst("Hash type=".count))
            } else if s.hasPrefix("Hash choices=") {
                hashChoices = String(s.dropFirst("Hash choices=".count))
            } else if s.hasPrefix("Signature=") {
                signatureType = String(s.dropFirst("Signature=".count))
            } else if s.hasPrefix("Format=") {
                format = String(s.dropFirst("Format=".count))
            } else if s.hasPrefix("Runtime Version=") {
                runtimeVersion = String(s.dropFirst("Runtime Version=".count))
            } else if s.hasPrefix("CMSDigest=") {
                cmsDigest = String(s.dropFirst("CMSDigest=".count))
            } else if s.hasPrefix("CMSDigestType=") {
                cmsDigestType = String(s.dropFirst("CMSDigestType=".count))
            } else if s.hasPrefix("Total signatures=") {
                totalSignatures = String(s.dropFirst("Total signatures=".count))
            } else if s.hasPrefix("Chosen signature=") {
                chosenSignature = String(s.dropFirst("Chosen signature=".count))
            } else if s.hasPrefix("Info.plist entries=") {
                infoPlistEntries = String(s.dropFirst("Info.plist entries=".count))
            } else if s.hasPrefix("CodeDirectory") {
                // 形如: CodeDirectory v=20400 size=52518 flags=0x2(adhoc) hashes=1635+3 location=embedded
                parseCodeDirectoryLine(s,
                                       version: &codeDirectoryVersion,
                                       size: &codeDirectorySize,
                                       flags: &flags,
                                       hashes: &codeDirectoryHashes,
                                       decoded: &decodedFlags)
            } else if s.hasPrefix("Sealed Resources") {
                // 形如: Sealed Resources version=2 rules=13 files=10
                parseSealedResourcesLine(s,
                                         version: &sealedResourcesVersion,
                                         rules: &sealedResourcesRules,
                                         files: &sealedResourcesFiles)
            } else if s.hasPrefix("Internal requirements") {
                // 形如: Internal requirements count=0 size=12
                internalRequirements = String(s.dropFirst("Internal requirements ".count))
            }
        }

        // 判断签名类型
        let state: CodeSignInfo.SignedState
        if let sig = signatureType, sig.lowercased().contains("adhoc") {
            state = .adhoc
        } else {
            state = .signed
        }

        // entitlements —— codesign 输出会先有诊断信息，再追加 XML plist；
        // 截取首个 "<?xml" 之后的内容用于解析。
        let entitlementsResult = runCodesign(args: ["-d", "--entitlements", ":-", bundleURL.path])
        var entitlementsRaw: String?
        var entitlements: [String: Any]?
        if !entitlementsResult.failed, !entitlementsResult.output.isEmpty {
            let raw = entitlementsResult.output
            if let xmlRange = raw.range(of: "<?xml") {
                let xml = String(raw[xmlRange.lowerBound...])
                entitlementsRaw = xml
                if let xmlData = xml.data(using: .utf8),
                   let pl = try? PropertyListSerialization.propertyList(
                       from: xmlData, options: [], format: nil) as? [String: Any] {
                    entitlements = pl
                }
            } else {
                entitlementsRaw = raw
            }
        }

        // Security framework 有效性验证
        let validity = checkValidity(bundleURL: bundleURL)
        // spctl 公证检查
        let notarization = checkNotarization(bundleURL: bundleURL)

        return CodeSignInfo(
            state: state,
            validity: validity,
            notarization: notarization,
            detailRaw: dvvv.output.isEmpty ? (dvvv.error) : dvvv.output,
            identifier: identifier,
            teamIdentifier: teamIdentifier,
            authorities: authorities,
            cdHash: cdHash,
            candidateCDHash: candidateCDHash,
            candidateCDHashFull: candidateCDHashFull,
            hashType: hashType,
            hashChoices: hashChoices,
            signatureType: signatureType,
            flags: flags,
            decodedFlags: decodedFlags,
            codeDirectoryVersion: codeDirectoryVersion,
            codeDirectorySize: codeDirectorySize,
            codeDirectoryHashes: codeDirectoryHashes,
            format: format,
            runtimeVersion: runtimeVersion,
            sealedResourcesVersion: sealedResourcesVersion,
            sealedResourcesRules: sealedResourcesRules,
            sealedResourcesFiles: sealedResourcesFiles,
            internalRequirements: internalRequirements,
            cmsDigest: cmsDigest,
            cmsDigestType: cmsDigestType,
            totalSignatures: totalSignatures,
            chosenSignature: chosenSignature,
            infoPlistEntries: infoPlistEntries,
            entitlementsRaw: entitlementsRaw,
            entitlements: entitlements,
            error: error
        )
    }

    private struct ShellResult {
        let output: String
        let failed: Bool
        let error: String
    }

    private static func runCodesign(args: [String]) -> ShellResult {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        proc.arguments = args
        // codesign 把 -dvvv 等诊断信息写到 stderr，合并到同一管道便于解析
        proc.standardOutput = pipe
        proc.standardError = pipe
        do {
            try proc.run()
        } catch {
            return ShellResult(output: "", failed: true, error: "无法启动 codesign: \(error.localizedDescription)")
        }
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let combined = String(data: data, encoding: .utf8) ?? ""
        let failed = proc.terminationStatus != 0
        return ShellResult(output: combined, failed: failed, error: combined)
    }

    // MARK: Line parsing helpers
    private static func parseCodeDirectoryLine(
        _ s: String,
        version: inout String?,
        size: inout String?,
        flags: inout String?,
        hashes: inout String?,
        decoded: inout [String]
    ) {
        // CodeDirectory v=20400 size=52518 flags=0x2(adhoc) hashes=1635+3 location=embedded
        let parts = s.split(separator: " ").map(String.init)
        for p in parts {
            if p.hasPrefix("v=") { version = String(p.dropFirst(2)) }
            else if p.hasPrefix("size=") { size = String(p.dropFirst(5)) }
            else if p.hasPrefix("hashes=") { hashes = String(p.dropFirst(7)) }
            else if p.hasPrefix("flags=") {
                flags = String(p.dropFirst(6))
                decoded = decodeFlags(p)
            }
        }
    }

    private static func parseSealedResourcesLine(
        _ s: String,
        version: inout String?,
        rules: inout String?,
        files: inout String?
    ) {
        // Sealed Resources version=2 rules=13 files=10   (或 none)
        if s.contains("=none") { return }
        let parts = s.split(separator: " ").map(String.init)
        for p in parts {
            if p.hasPrefix("version=") { version = String(p.dropFirst(8)) }
            else if p.hasPrefix("rules=") { rules = String(p.dropFirst(6)) }
            else if p.hasPrefix("files=") { files = String(p.dropFirst(6)) }
        }
    }

    /// 解码 flags 字符串形如 "0x10002(adhoc,runtime)" -> ["adhoc","runtime"]
    private static func decodeFlags(_ raw: String) -> [String] {
        guard let open = raw.firstIndex(of: "("),
              let close = raw.firstIndex(of: ")") else { return [] }
        let inside = raw[raw.index(after: open)..<close]
        return inside.split(separator: ",").map(String.init)
    }

    // MARK: Validity & Notarization
    private static func checkValidity(bundleURL: URL) -> CodeSignInfo.Validity {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(
            bundleURL as CFURL,
            SecCSFlags(rawValue: 0),
            &staticCode
        )
        guard createStatus == errSecSuccess, let code = staticCode else {
            return .invalid
        }
        let flags: SecCSFlags = SecCSFlags(rawValue: kSecCSBasicValidateOnly)
        let validStatus = SecStaticCodeCheckValidity(code, flags, nil)
        return validStatus == errSecSuccess ? .valid : .invalid
    }

    /// spctl -a -vvv <bundle> 检查 Gatekeeper / 公证。
    private static func checkNotarization(bundleURL: URL) -> CodeSignInfo.Notarization {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/spctl")
        proc.arguments = ["-a", "-vvv", bundleURL.path]
        proc.standardOutput = pipe
        proc.standardError = pipe
        do { try proc.run() } catch { return .unknown }
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        // 正式带公证票据的输出包含 "notarized"：
        //   "source=Notarized Developer ID"
        //   "originator=Developer ID Application: ..."
        if text.lowercased().contains("notarized") {
            return .notarized
        }
        // 即使没票据，spctl 也会给出 source=...; 否则视为未公证。
        // 调用 exit 非零也视为未公证。
        return proc.terminationStatus == 0 ? .notarized : .notNotarized
    }
}