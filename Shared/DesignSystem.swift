import SwiftUI

struct VibrantBackground: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            // Dark base background
            Color(red: 0.05, green: 0.04, blue: 0.04)
                .ignoresSafeArea()
            
            // Soft large radial glow
            RadialGradient(
                gradient: Gradient(colors: [Color.flintRed.opacity(0.32), Color.clear]),
                center: .center,
                startRadius: 10,
                endRadius: 420
            )
            .offset(y: 80)
            .ignoresSafeArea()
            
            content
        }
    }
}

extension View {
    func vibrantBackground() -> some View {
        self.modifier(VibrantBackground())
    }
}

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

extension View {
    func glassCard() -> some View {
        self.modifier(GlassCard())
    }
}

struct PillButtonStyle: ButtonStyle {
    var color: Color = Color.flintRed
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).bold())
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(Capsule().fill(color))
            .shadow(color: color.opacity(0.4), radius: 10, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
