import Foundation
import SwiftUI

// MARK: - 全局应用状态

/// 应用偏好：语言、主题色。@AppStorage 自动持久化到 UserDefaults。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case zh     = "zh"
    case en     = "en"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return L10n.t(.langSystem)
        case .zh:     return "中文"
        case .en:     return "English"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return L10n.t(.themeSystem)
        case .light:  return L10n.t(.themeLight)
        case .dark:   return L10n.t(.themeDark)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

final class AppState: ObservableObject {
    @AppStorage("swiftlens.language") var language: AppLanguage = .system
    @AppStorage("swiftlens.theme")   var theme: AppTheme = .system
}