import SwiftUI

struct AnimatedThemeBackground: View {
    let theme: AppTheme
    @State private var breathe = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.background, theme.surface, theme.glow.opacity(0.34), theme.background],
                startPoint: breathe ? .topLeading : .topTrailing,
                endPoint: breathe ? .bottomTrailing : .bottomLeading
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [theme.secondary.opacity(breathe ? 0.18 : 0.10), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
                Spacer()
                LinearGradient(
                    colors: [.clear, theme.primary.opacity(breathe ? 0.10 : 0.16)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 260)
            }
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true), value: breathe)
        .onAppear { breathe = true }
    }
}
