import Foundation

// MARK: - 扩展属性全列表

/// 读取 .app bundle 上挂载的全部扩展属性 (xattrs)。
struct ExtendedXattrInfo {
    let names: [String]            // 所有 xattr 名称
    let descriptions: [String: String]  // 各 xattr 的原始值（不可读则提示 <binary>）
}

enum ExtendedXattrReader {

    /// 读取指定 URL 的全部扩展属性。
    static func read(for url: URL) -> ExtendedXattrInfo {
        let path = url.path
        // 1. 取 buffer 长度
        let length = listxattr(path, nil, 0, 0)
        guard length > 0 else {
            return ExtendedXattrInfo(names: [], descriptions: [:])
        }
        var buffer = [CChar](repeating: 0, count: length + 1)
        let used = listxattr(path, &buffer, buffer.count, 0)
        guard used > 0 else {
            return ExtendedXattrInfo(names: [], descriptions: [:])
        }
        // 原始 C 字符串里多个 name 以 NUL 分隔，末尾是双 NUL
        let bytes = buffer.prefix(used)
        let raw = String(cString: Array(bytes) + [0])
        let names = raw.split(separator: "\0", omittingEmptySubsequences: true).map(String.init)

        var desc: [String: String] = [:]
        for name in names {
            desc[name] = name.withCString { cName in
                readValue(path: path, name: cName)
            }
        }
        return ExtendedXattrInfo(names: names, descriptions: desc)
    }

    private static func readValue(path: String, name: UnsafePointer<CChar>) -> String {
        let len = getxattr(path, name, nil, 0, 0, 0)
        if len <= 0 { return "<空>" }
        var buf = [UInt8](repeating: 0, count: len + 1)
        let read = buf.withUnsafeMutableBytes { ptr -> Int in
            getxattr(path, name, ptr.baseAddress, len, 0, 0)
        }
        guard read > 0 else { return "<无法读取>" }
        let data = Data(buf.prefix(read))
        // 尝试打印为 UTF-8 文本
        if let s = String(data: data, encoding: .utf8) {
            let printableRatio = s.filter { $0.isLetter || $0.isNumber || $0.isPunctuation || $0.isWhitespace || $0.isSymbol }.count
            if printableRatio >= s.count / 2 || s.count <= 16 {
                return s
            }
        }
        // com.apple.macl 等是二进制 —— 显示为十六进制
        if data.count <= 128 {
            return "0x" + data.map { String(format: "%02x", $0) }.joined()
        }
        return "0x" + data.prefix(64).map { String(format: "%02x", $0) }.joined() + "… (\(data.count) bytes)"
    }
}