//
//  GradientColor.swift
//  FlintItApp
//
//  Created by Elvira Oktaviani on 15/07/26.
//

import SwiftUI

struct GradientBackground: View {

    var body: some View {

        ZStack {

            // Base Background
            Color.black
                .ignoresSafeArea()

            // Top Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                           // Color.red.opacity(0.45),
                            Color.red.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 250
                    )
                )
                .frame(width: 350, height: 350)
                .offset(x: 140, y: -250)

            // Bottom Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.orange.opacity(0.18),
                            .clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 260
                    )
                )
                .frame(width: 350, height: 350)
                .offset(x: -160, y: 320)

            // Dark Overlay
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.35),
                    Color.black.opacity(0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

        }
        .ignoresSafeArea()

    }
}

#Preview {
    GradientBackground()
}
