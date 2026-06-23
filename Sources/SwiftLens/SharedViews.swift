import SwiftUI
import AppKit

/// 复制到剪贴板
func copyToPasteboard(_ string: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
}

/// 单行 键 -> 值 展示，支持长按 / 右键复制。
struct RowView: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(key)
                .font(.system(.body, design: .default))
                .foregroundStyle(.secondary)
                .frame(width: 200, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(value.isEmpty ? "—" : value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contextMenu {
            Button("复制值") { copyToPasteboard(value) }
            Button("复制键值") { copyToPasteboard("\(key): \(value)") }
        }
    }
}

/// 标题分区。
struct SectionView<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                if let s = subtitle {
                    Text(s)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.4)))
            Divider().opacity(0.3)
        }
    }
}

/// 通用占用提示。
struct PlaceholderRow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(.body).italic())
            .foregroundStyle(.secondary)
    }
}