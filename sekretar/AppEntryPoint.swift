import SwiftUI

/// Entry point с launch screen анимацией
struct AppEntryPoint: View {
    @State private var showLaunchScreen = true

    var body: some View {
        ZStack {
            // Main app content
            DemoContentView()
                .opacity(showLaunchScreen ? 0 : 1)

            // Launch screen overlay
            if showLaunchScreen {
                LaunchScreen()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            // Show launch screen for 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showLaunchScreen = false
                }
            }
        }
    }
}
