import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// Дизайн-токены
struct AppTheme {
    var cornerRadius: CGFloat = 16
    var spacing: CGFloat = 12
    struct Palette {
        var bg: Color = {
#if canImport(UIKit)
            return Color(UIColor.systemBackground)
#elseif canImport(AppKit)
            return Color(NSColor.windowBackgroundColor)
#else
            return Color.white
#endif
        }()
        var card: Color = {
#if canImport(UIKit)
            return Color(UIColor.secondarySystemBackground)
#elseif canImport(AppKit)
            return Color(NSColor.controlBackgroundColor)
#else
            return Color.white.opacity(0.95)
#endif
        }()
        var text = Color.primary
        var subtle = Color.secondary.opacity(0.2)
        var positive = Color.green
        var warning = Color.orange
    }
    var colors = Palette()
}

// Environment для темы
private struct AppThemeKey: EnvironmentKey { static let defaultValue = AppTheme() }
extension EnvironmentValues { var theme: AppTheme {
    get { self[AppThemeKey.self] } set { self[AppThemeKey.self] = newValue }
}}
extension View { func appTheme(_ theme: AppTheme = .init()) -> some View {
    environment(\.theme, theme)
}}

// Карточный стиль
struct CardStyle: ViewModifier {
    @Environment(\.theme) private var theme
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
    }
}
extension View { func card() -> some View { modifier(CardStyle()) } }
