import SwiftUI

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.4, blue: 0.8),
                    Color(red: 0.0, green: 0.2, blue: 0.5)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Dolphin Icon
                DolphinIcon()
                    .frame(width: 200, height: 200)

                // App Name
                Text("Sekretar")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Tagline
                Text("AI Calendar Assistant")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

struct DolphinIcon: View {
    var body: some View {
        ZStack {
            // Main body
            Path { path in
                // Dolphin body shape
                path.move(to: CGPoint(x: 100, y: 50))
                path.addCurve(
                    to: CGPoint(x: 180, y: 80),
                    control1: CGPoint(x: 140, y: 30),
                    control2: CGPoint(x: 170, y: 50)
                )
                path.addCurve(
                    to: CGPoint(x: 160, y: 150),
                    control1: CGPoint(x: 190, y: 110),
                    control2: CGPoint(x: 180, y: 140)
                )
                path.addCurve(
                    to: CGPoint(x: 100, y: 180),
                    control1: CGPoint(x: 140, y: 160),
                    control2: CGPoint(x: 120, y: 180)
                )
                path.addCurve(
                    to: CGPoint(x: 40, y: 140),
                    control1: CGPoint(x: 80, y: 180),
                    control2: CGPoint(x: 50, y: 165)
                )
                path.addCurve(
                    to: CGPoint(x: 60, y: 80),
                    control1: CGPoint(x: 30, y: 115),
                    control2: CGPoint(x: 40, y: 95)
                )
                path.addCurve(
                    to: CGPoint(x: 100, y: 50),
                    control1: CGPoint(x: 70, y: 65),
                    control2: CGPoint(x: 85, y: 50)
                )
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.0, green: 0.4, blue: 0.7),
                        Color(red: 0.0, green: 0.6, blue: 0.9)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 5, y: 5)

            // Highlight
            Path { path in
                path.move(to: CGPoint(x: 110, y: 70))
                path.addCurve(
                    to: CGPoint(x: 150, y: 90),
                    control1: CGPoint(x: 130, y: 65),
                    control2: CGPoint(x: 145, y: 75)
                )
                path.addCurve(
                    to: CGPoint(x: 140, y: 120),
                    control1: CGPoint(x: 155, y: 105),
                    control2: CGPoint(x: 150, y: 115)
                )
                path.addCurve(
                    to: CGPoint(x: 110, y: 70),
                    control1: CGPoint(x: 120, y: 110),
                    control2: CGPoint(x: 110, y: 90)
                )
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.4),
                        Color.white.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Eye
            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
                .position(x: 155, y: 75)

            Circle()
                .fill(Color(red: 0.0, green: 0.2, blue: 0.4))
                .frame(width: 6, height: 6)
                .position(x: 155, y: 75)

            // Beak/Snout
            Path { path in
                path.move(to: CGPoint(x: 180, y: 80))
                path.addLine(to: CGPoint(x: 200, y: 85))
                path.addLine(to: CGPoint(x: 200, y: 95))
                path.addLine(to: CGPoint(x: 180, y: 95))
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.0, green: 0.5, blue: 0.8),
                        Color(red: 0.3, green: 0.7, blue: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Dorsal fin
            Path { path in
                path.move(to: CGPoint(x: 110, y: 60))
                path.addCurve(
                    to: CGPoint(x: 130, y: 40),
                    control1: CGPoint(x: 115, y: 50),
                    control2: CGPoint(x: 125, y: 42)
                )
                path.addCurve(
                    to: CGPoint(x: 140, y: 60),
                    control1: CGPoint(x: 135, y: 38),
                    control2: CGPoint(x: 145, y: 50)
                )
                path.addLine(to: CGPoint(x: 110, y: 60))
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.0, green: 0.3, blue: 0.6),
                        Color(red: 0.0, green: 0.5, blue: 0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Tail fin
            Path { path in
                path.move(to: CGPoint(x: 40, y: 140))
                path.addCurve(
                    to: CGPoint(x: 10, y: 120),
                    control1: CGPoint(x: 25, y: 135),
                    control2: CGPoint(x: 15, y: 128)
                )
                path.addCurve(
                    to: CGPoint(x: 20, y: 160),
                    control1: CGPoint(x: 5, y: 140),
                    control2: CGPoint(x: 10, y: 155)
                )
                path.addLine(to: CGPoint(x: 40, y: 140))
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.0, green: 0.4, blue: 0.7),
                        Color(red: 0.0, green: 0.6, blue: 0.9)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            // Belly highlight
            Path { path in
                path.move(to: CGPoint(x: 80, y: 150))
                path.addCurve(
                    to: CGPoint(x: 130, y: 145),
                    control1: CGPoint(x: 100, y: 155),
                    control2: CGPoint(x: 120, y: 153)
                )
                path.addCurve(
                    to: CGPoint(x: 140, y: 140),
                    control1: CGPoint(x: 135, y: 143),
                    control2: CGPoint(x: 140, y: 141)
                )
                path.addCurve(
                    to: CGPoint(x: 80, y: 150),
                    control1: CGPoint(x: 120, y: 155),
                    control2: CGPoint(x: 100, y: 160)
                )
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.3),
                        Color.white.opacity(0.05)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(width: 200, height: 200)
    }
}

#Preview {
    LaunchScreen()
}
