import SwiftUI

struct VibrantBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            // Dark base background
            Color(red: 0.05, green: 0.04, blue: 0.04)
                .ignoresSafeArea()
            
            // Soft large radial glow centered at the bottom half to match the red glow in the screenshots
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

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    #if os(iOS)
                    .background(
                        VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    )
                    #endif
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

// Helper untuk efek blur Apple bawaan (Glassmorphism) - Hanya untuk iOS karena watchOS tidak mendukung UIKit
#if os(iOS)
import UIKit

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
#endif

// Mempermudah pemanggilan di file UI
extension View {
    func flintVibrantBackground() -> some View {
        self.modifier(VibrantBackgroundModifier())
    }
    
    func flintGlassCard() -> some View {
        self.modifier(GlassCardModifier())
    }
}
