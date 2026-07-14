import SwiftUI

struct FlintPrimaryButtonStyle: ButtonStyle {
    var isWhite: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundColor(isWhite ? .flintRed : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isWhite ? Color.white : Color.flintRed)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
            .shadow(color: isWhite ? .clear : Color.flintRed.opacity(0.5), radius: 10, x: 0, y: 5)
    }
}
