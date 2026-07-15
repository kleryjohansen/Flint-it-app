import SwiftUI

struct VibrantBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        ZStack {
            if colorScheme == .light {
                // Light mode: clean white blending to dynamic primary red-orange at the bottom
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
                // Dark mode: pitch black blending to deep primary red-orange at the bottom
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
            
            // Central radial glow around the central button matching the mockup glow
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

struct GlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.flintGlass)
                    #if os(iOS)
                    .background(
                        VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    )
                    #endif
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.flintCardBorder, lineWidth: 1)
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
