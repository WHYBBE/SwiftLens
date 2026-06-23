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

    let state: SignedState
    let validity: Validity
    let detailRaw: String          // codesign -dvvv 完整输出
    let identifier: String?
    let teamIdentifier: String?
    let authorities: [String]
    let cdHash: String?
    let hashType: String?
    let signatureType: String?     // "adhoc" / "valid" / ...
    let flags: String?
    let codeDirectoryVersion: String?
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
        var hashType: String?
        var signatureType: String?
        var flags: String?
        var codeDirectoryVersion: String?
        var error: String?

        let dvvv = runCodesign(args: ["-dvvv", bundleURL.path])
        if dvvv.failed {
            error = dvvv.error
            // 可能未签名
            if dvvv.error.contains("not signed at all") {
                return CodeSignInfo(
                    state: .unsigned, validity: .untested,
                    detailRaw: dvvv.error, identifier: nil, teamIdentifier: nil,
                    authorities: [], cdHash: nil, hashType: nil, signatureType: nil,
                    flags: nil, codeDirectoryVersion: nil,
                    entitlementsRaw: nil, entitlements: nil, error: error
                )
            }
        }

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
            } else if s.hasPrefix("Hash type=") {
                hashType = String(s.dropFirst("Hash type=".count))
            } else if s.hasPrefix("Signature=") {
                signatureType = String(s.dropFirst("Signature=".count))
            } else if s.hasPrefix("flags=") {
                flags = String(s.dropFirst("flags=".count))
            } else if s.hasPrefix("CodeDirectory v=") {
                codeDirectoryVersion = String(s.dropFirst("CodeDirectory v=".count))
            }
        }

        // 判断签名类型
        let state: CodeSignInfo.SignedState
        if let sig = signatureType, sig.lowercased().contains("adhoc") {
            state = .adhoc
        } else {
            state = .signed
        }

        // entitlements —— codesign 会先输出常规诊断信息再追加 XML plist；
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

        // 通过 Security framework 进行有效性验证
        let validity = checkValidity(bundleURL: bundleURL)

        return CodeSignInfo(
            state: state,
            validity: validity,
            detailRaw: dvvv.output.isEmpty ? (dvvv.error) : dvvv.output,
            identifier: identifier,
            teamIdentifier: teamIdentifier,
            authorities: authorities,
            cdHash: cdHash,
            hashType: hashType,
            signatureType: signatureType,
            flags: flags,
            codeDirectoryVersion: codeDirectoryVersion,
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
}