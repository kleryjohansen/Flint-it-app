import SwiftUI

struct FlintPrimaryButtonStyle: ButtonStyle {
    var isWhite: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .default))
            .foregroundColor(isWhite ? .flintRed : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isWhite ? Color.white : Color.flintRed)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: configuration.isPressed)
            .shadow(color: isWhite ? .clear : Color.flintRed.opacity(0.35), radius: 12, x: 0, y: 6)
    }
}
