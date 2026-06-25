import SwiftUI
import AppKit

// MARK: - 设置面板

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 标题行
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(L10n.t(.settings))
                    .font(.title2.bold())
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .help(L10n.t(.close))
            }

            // 语言
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.t(.language), systemImage: "globe")
                    .font(.headline)
                Picker(L10n.t(.language), selection: bindingLanguage) {
                    ForEach(AppLanguage.allCases) { l in
                        Text(l.displayName).tag(l)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 400)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 主题
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.t(.theme), systemImage: "sun.max.fill")
                    .font(.headline)
                Picker(L10n.t(.theme), selection: bindingTheme) {
                    ForEach(AppTheme.allCases) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 400)
                .onChange(of: appState.theme) { _ in
                    // 切换时直接给已经存在的窗口广播一个通知，确保色板立即生效
                    NotificationCenter.default.post(name: .themeDidChange, object: nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 占位提示
            Text(verbatim: "SwiftLens 1.0")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(28)
        .frame(width: 480, height: 280)
        .background(.regularMaterial)
    }

    // AppStorage 双向绑定 (枚举) 需要走 String 中介
    private var bindingLanguage: Binding<AppLanguage> {
        Binding(
            get: { appState.language },
            set: { appState.language = $0 }
        )
    }
    private var bindingTheme: Binding<AppTheme> {
        Binding(
            get: { appState.theme },
            set: { appState.theme = $0 }
        )
    }
}

extension Notification.Name {
    static let themeDidChange = Notification.Name("SwiftLens.themeDidChange")
}