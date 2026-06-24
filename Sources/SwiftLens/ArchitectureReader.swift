import Foundation
import MachO

// MARK: - Mach-O 架构解析

/// 解析 .app bundle 主可执行文件包含的 CPU 架构列表。
/// 支持普通 Mach-O 以及通用 (Fat) 二进制。
enum ArchitectureReader {

    struct ArchInfo {
        let name: String
        let cpuType: String
        let bits: Int            // 32 / 64
        let fileSize: UInt64
        let offsetInFat: UInt64  // 在 fat 二进制中的偏移；非 fat 则为 0
    }

    static func read(for bundleURL: URL) -> [ArchInfo] {
        let execURL = bundleURL.appendingPathComponent("Contents/MacOS")
        // 优先从 Info.plist 的 CFBundleExecutable 中拿到主可执行文件名，
        // 因 Contents/MacOS 可能还包含资源子目录，按字母序会选到错误条目。
        let execName: String?
        if let plist = InfoPlistParser.parse(at: bundleURL),
           let name = plist["CFBundleExecutable"] as? String {
            execName = name
        } else {
            execName = try? FileManager.default
                .contentsOfDirectory(atPath: execURL.path)
                .first(where: { !isDirectory(at: execURL.appendingPathComponent($0)) })
        }
        guard let name = execName else { return [] }
        let execPath = execURL.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: execPath) else { return [] }
        guard data.count >= 4 else { return [] }

        let magBE = data.readUInt32BE(at: 0)

        // Fat / Universal binary (fat 头总是大端存储)
        if magBE == FAT_MAGIC || magBE == FAT_MAGIC_64 {
            return parseFat(data: data, is64: magBE == FAT_MAGIC_64, execPath: execPath)
        }
        // 普通 Mach-O
        if let single = parseSingle(data: data, fatOffset: 0, execPath: execPath) {
            return [single]
        }
        return []
    }

    private static func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private static func fileSize(of execPath: URL) -> UInt64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: execPath.path),
              let size = attrs[.size] as? UInt64 else { return 0 }
        return size
    }

    private static func parseFat(data: Data, is64: Bool, execPath: URL) -> [ArchInfo] {
        let nfat = data.readUInt32BE(at: 4)
        var archs: [ArchInfo] = []
        var off = 8
        let archSize = is64 ? 32 : 20  // fat_arch_64 = 32, fat_arch = 20

        for _ in 0..<Int(nfat) {
            guard off + archSize <= data.count else { break }
            let cpuType = Int32(bitPattern: data.readUInt32BE(at: off))
            let cpuSub  = Int32(bitPattern: data.readUInt32BE(at: off + 4))
            let thingOffset: UInt64
            let thingSize: UInt64
            if is64 {
                thingOffset = data.readUInt64BE(at: off + 8)
                thingSize   = data.readUInt64BE(at: off + 16)
            } else {
                thingOffset = UInt64(data.readUInt32BE(at: off + 8))
                thingSize   = UInt64(data.readUInt32BE(at: off + 12))
            }
            let (name, cpuName, bits) = describeCpu(cpuType, subtype: cpuSub)
            archs.append(ArchInfo(
                name: name,
                cpuType: cpuName,
                bits: bits,
                fileSize: thingSize,
                offsetInFat: thingOffset
            ))
            off += archSize
        }
        _ = execPath
        return archs
    }

    private static func parseSingle(data: Data, fatOffset: UInt64, execPath: URL) -> ArchInfo? {
        guard data.count >= Int(fatOffset) + 28 else { return nil }
        let magBE = data.readUInt32BE(at: Int(fatOffset))
        let magLE = data.readUInt32LE(at: Int(fatOffset))
        let bigEndian: Bool
        switch magBE {
        case UInt32(MH_MAGIC), UInt32(MH_MAGIC_64):
            // 大端存储：magic 以 BE 方式解读后等于 MH_MAGIC*
            bigEndian = true
        case UInt32(MH_CIGAM), UInt32(MH_CIGAM_64):
            // BE 解读得到 CIGAM，说明实际是小端
            bigEndian = false
        default:
            // 兜底：字节序由 LE 解读后是否等于 MH_MAGIC* 决定
            if magLE == UInt32(MH_MAGIC) || magLE == UInt32(MH_MAGIC_64) {
                bigEndian = false
            } else if magLE == UInt32(MH_CIGAM) || magLE == UInt32(MH_CIGAM_64) {
                bigEndian = true
            } else {
                return nil
            }
        }
        let raw = bigEndian ? data.readUInt32BE(at: Int(fatOffset) + 4)
                            : data.readUInt32LE(at: Int(fatOffset) + 4)
        let cputype = Int32(bitPattern: raw)
        // mach_header 之后是 cpusubtype (4 字节); 为判别 arm64e 同样需读取
        let subRaw = bigEndian ? data.readUInt32BE(at: Int(fatOffset) + 8)
                               : data.readUInt32LE(at: Int(fatOffset) + 8)
        let cpusubtype = Int32(bitPattern: subRaw)
        let size = fileSize(of: execPath)
        let (name, cpuName, bits) = describeCpu(cputype, subtype: cpusubtype)
        return ArchInfo(name: name, cpuType: cpuName, bits: bits, fileSize: size, offsetInFat: fatOffset)
    }

    private static func describeCpu(_ cputype: Int32, subtype: Int32) -> (name: String, cpuType: String, bits: Int) {
        switch cputype {
        case CPU_TYPE_ARM64:
            // CPU_SUBTYPE_ARM64E = 2 (带指针身份验证扩展)。
            // mach_header 中 cpusubtype 高位常被设为库授权位 (0x80000000)，需要屏蔽。
            let sub = UInt32(bitPattern: subtype) & 0x00FFFFFF
            if sub == 2 { return ("arm64e", "ARM 64-bit (arm64e, 带指针身份验证)", 64) }
            if sub == 0 { return ("arm64", "ARM 64-bit", 64) }
            return ("arm64(sub=\(sub))", "ARM 64-bit", 64)
        case CPU_TYPE_ARM:
            return ("arm", "ARM", 32)
        case CPU_TYPE_X86_64:
            return ("x86_64", "Intel x86_64", 64)
        case CPU_TYPE_X86:
            return ("i386", "Intel x86", 32)
        case CPU_TYPE_POWERPC64:
            return ("ppc64", "PowerPC 64-bit", 64)
        case CPU_TYPE_POWERPC:
            return ("ppc", "PowerPC", 32)
        default:
            return ("unknown(0x\(String(UInt32(bitPattern: cputype), radix: 16)))", "Unknown", 0)
        }
    }
}

// MARK: - Data 拓展
private extension Data {
    func readUInt32BE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset]) << 24 |
               UInt32(self[offset + 1]) << 16 |
               UInt32(self[offset + 2]) << 8 |
               UInt32(self[offset + 3])
    }
    func readUInt32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset]) |
               UInt32(self[offset + 1]) << 8 |
               UInt32(self[offset + 2]) << 16 |
               UInt32(self[offset + 3]) << 24
    }
    func readUInt64BE(at offset: Int) -> UInt64 {
        guard offset + 8 <= count else { return 0 }
        var v: UInt64 = 0
        for i in 0..<8 { v = (v << 8) | UInt64(self[offset + i]) }
        return v
    }
}