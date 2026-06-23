import Foundation

// MARK: - Quarantine 扩展属性

/// 读取 com.apple.quarantine 扩展属性信息。
/// 原始格式形如:  "0083;62XXXXXX;Safari;F2BXXXXX"
/// 字段含义:
///   - flags         Gatekeeper 标志 (4 字符十六进制)
///   - timestamp     应用下载时的 Unix 时间戳 (十六进制字符串)
///   - agent         下载该应用的进程/应用名称
///   - uuid          下载事件 UUID (十六进制)
struct QuarantineInfo {
    let raw: String
    let flags: String
    let agent: String
    let timestampString: String
    let downloadDate: Date?
}

enum QuarantineReader {

    static func read(for url: URL) -> QuarantineInfo? {
        let path = url.path
        let name = "com.apple.quarantine"
        // 1. 取长度
        let length = getxattr(path, name, nil, 0, 0, 0)
        guard length > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: length + 1)
        let read = getxattr(path, name, &buffer, length, 0, 0)
        guard read > 0 else { return nil }

        let raw = String(cString: buffer)
        let parts = raw.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
        let flags = parts.count > 0 ? parts[0] : ""
        let ts    = parts.count > 1 ? parts[1] : ""
        let agent = parts.count > 2 ? parts[2] : ""
        let uuid  = parts.count > 3 ? parts[3] : ""

        var date: Date?
        if let secs = UInt64(ts, radix: 16) {
            date = Date(timeIntervalSince1970: TimeInterval(secs))
        }
        _ = uuid
        return QuarantineInfo(
            raw: raw,
            flags: flags,
            agent: agent,
            timestampString: ts,
            downloadDate: date
        )
    }

    /// 删除指定 URL 的 com.apple.quarantine 扩展属性。
    /// - Returns: 成功返回 nil，失败返回错误描述。
    @discardableResult
    static func remove(for url: URL) -> String? {
        let path = url.path
        let res = removexattr(path, "com.apple.quarantine", 0)
        if res == 0 { return nil }
        let code = errno
        return String(cString: strerror(code))
    }
}