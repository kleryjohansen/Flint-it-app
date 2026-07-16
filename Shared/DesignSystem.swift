import SwiftUI

struct PillButtonStyle: ButtonStyle {
    var color: Color = Color.flintRed

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundColor(.white) // Intentional: di atas fixed brand background
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(Capsule().fill(color))
            .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
