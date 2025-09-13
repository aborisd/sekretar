import SwiftUI

enum UI {
    // Цвета
    static let bg = Color(white: 0.96)          // фон экранов (в тёмной теме можно поменять на .black.opacity(0.92))
    static let surface = Color.white            // фон карточек/инпутов
    static let accent = Color.blue

    // Плотность (правишь один раз — меняется везде)
    static let pad: CGFloat = 12                // базовые горизонтальные отступы
    static let gap: CGFloat = 8                 // расстояние между элементами
    static let radius: CGFloat = 12             // скругление
    static let stroke = Color.black.opacity(0.08)
}
