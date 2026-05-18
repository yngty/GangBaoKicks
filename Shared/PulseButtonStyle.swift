import SwiftUI

struct PulseButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 12)
            .frame(minHeight: 52)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .shadow(color: tint.opacity(configuration.isPressed ? 0.10 : 0.28), radius: configuration.isPressed ? 4 : 12, y: configuration.isPressed ? 2 : 7)
            .animation(.spring(response: 0.22, dampingFraction: 0.62), value: configuration.isPressed)
    }
}
