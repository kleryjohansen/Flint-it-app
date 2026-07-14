import SwiftUI

struct VibrantBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            // Base dark background
            Color.flintBackground.ignoresSafeArea()
            
            // Glowing radial red at the center/bottom
            RadialGradient(
                gradient: Gradient(colors: [Color.flintRed.opacity(0.6), Color.clear]),
                center: .bottom,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            content
        }
    }
}

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.flintGlass)
                    .background(
                        VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

// Helper untuk efek blur Apple bawaan (Glassmorphism)
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// Mempermudah pemanggilan di file UI
extension View {
    func flintVibrantBackground() -> some View {
        self.modifier(VibrantBackgroundModifier())
    }
    
    func flintGlassCard() -> some View {
        self.modifier(GlassCardModifier())
    }
}
