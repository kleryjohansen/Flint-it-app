import SwiftUI

struct FlintPrimaryButtonStyle: ButtonStyle {
    var isWhite: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.bold())
            .foregroundColor(isWhite ? .flintRed : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                if isWhite {
                    Color.white
                } else {
                    Capsule().fill(Color.flintRed.opacity(0.85))
                }
            }
            .glassEffect(.regular.interactive(), in: .capsule)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: configuration.isPressed)
            .shadow(color: isWhite ? .clear : Color.flintRed.opacity(0.25), radius: 12, x: 0, y: 6)
    }
}

struct FlameGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 180, height: 180)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color("appFlameHighlight"), Color.flintRed],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .glassEffect(.regular.interactive(), in: .circle)
            .shadow(color: Color.flintRed.opacity(0.4), radius: 12, y: 6)
    }
}
