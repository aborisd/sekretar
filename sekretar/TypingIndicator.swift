import SwiftUI

/// Анимированный индикатор "печатания" как в iMessage
/// Три точки пульсируют по очереди
struct TypingIndicator: View {
    @State private var animatingDot1 = false
    @State private var animatingDot2 = false
    @State private var animatingDot3 = false

    let dotSize: CGFloat = 8
    let spacing: CGFloat = 4

    var body: some View {
        HStack(spacing: spacing) {
            Circle()
                .fill(Color.secondary.opacity(0.6))
                .frame(width: dotSize, height: dotSize)
                .scaleEffect(animatingDot1 ? 1.0 : 0.5)
                .animation(
                    Animation.easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(0.0),
                    value: animatingDot1
                )

            Circle()
                .fill(Color.secondary.opacity(0.6))
                .frame(width: dotSize, height: dotSize)
                .scaleEffect(animatingDot2 ? 1.0 : 0.5)
                .animation(
                    Animation.easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(0.2),
                    value: animatingDot2
                )

            Circle()
                .fill(Color.secondary.opacity(0.6))
                .frame(width: dotSize, height: dotSize)
                .scaleEffect(animatingDot3 ? 1.0 : 0.5)
                .animation(
                    Animation.easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(0.4),
                    value: animatingDot3
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.gray.opacity(0.1))
        )
        .onAppear {
            animatingDot1 = true
            animatingDot2 = true
            animatingDot3 = true
        }
    }
}

// MARK: - Preview

struct TypingIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            TypingIndicator()

            // Пример в контексте чата
            HStack {
                TypingIndicator()
                Spacer()
            }
            .padding()
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
