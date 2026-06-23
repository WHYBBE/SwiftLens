import Foundation

// MARK: - Info.plist 解析

/// 从 .app bundle 的 Info.plist 中读取所有键值，并解析常用字段。
enum InfoPlistParser {

    /// 读取 .app bundle 的 Info.plist 为字典。
    static func parse(at bundleURL: URL) -> [String: Any]? {
        let plistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return nil }
        guard let data = try? Data(contentsOf: plistURL) else { return nil }
        return try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any]
    }

    /// 将任意 plist 值规整为可展示字符串。
    static func describe(_ value: Any) -> String {
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        if let b = value as? Bool { return b ? "YES" : "NO" }
        if let d = value as? Data { return "Data (\(d.count) bytes)" }
        if let date = value as? Date { return ISO8601DateFormatter().string(from: date) }
        if let arr = value as? [Any] {
            return arr.map { describe($0) }.joined(separator: ", ")
        }
        if let dict = value as? [String: Any] {
            return dict.map { "\($0.key): \(describe($0.value))" }.joined(separator: ", ")
        }
        return String(describing: value)
    }

    /// 把 plist 字典扁平化为 (key, value) 排序列表，嵌套字典以 "a.b.c" 形式展开。
    static func flatten(_ dict: [String: Any], prefix: String = "") -> [(String, String)] {
        var rows: [(String, String)] = []
        let keys = dict.keys.sorted()
        for key in keys {
            let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"
            let value = dict[key]
            if let nested = value as? [String: Any] {
                rows.append(contentsOf: flatten(nested, prefix: fullKey))
            } else if let arr = value as? [Any] {
                if arr.contains(where: { $0 is [String: Any] }) {
                    for (i, el) in arr.enumerated() {
                        if let d = el as? [String: Any] {
                            rows.append(contentsOf: flatten(d, prefix: "\(fullKey)[\(i)]"))
                        } else {
                            rows.append(("\(fullKey)[\(i)]", describe(el)))
                        }
                    }
                } else {
                    rows.append((fullKey, describe(arr)))
                }
            } else {
                rows.append((fullKey, describe(value ?? "")))
            }
        }
        return rows
    }
}