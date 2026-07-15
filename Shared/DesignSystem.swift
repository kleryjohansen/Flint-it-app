import SwiftUI

struct VibrantBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        ZStack {
            if colorScheme == .light {
                LinearGradient(
                    colors: [
                        Color.white,
                        Color.white.opacity(0.9),
                        Color("appPrimary").opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.black.opacity(0.85),
                        Color("appPrimaryDeep").opacity(0.65)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            
            RadialGradient(
                gradient: Gradient(colors: [
                    Color("appPrimary").opacity(colorScheme == .light ? 0.25 : 0.35),
                    Color.clear
                ]),
                center: .center,
                startRadius: 10,
                endRadius: 260
            )
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
                    .fill(Color.flintGlass)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.flintCardBorder, lineWidth: 1)
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
            .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
