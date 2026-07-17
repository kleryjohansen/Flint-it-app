import SwiftUI

/// Panah arah presisi yang lebih besar & jelas dibanding SF Symbol kecil.
/// Desain: batang vertikal (mirip huruf "I") + kepala panah segitiga.
/// Cocok untuk UX "Find Partner" di NearbyRadarView.
struct DirectionalArrowView: View {
    let angleDegrees: Double
    let isOnTarget: Bool

    private var arrowColor: Color {
        isOnTarget ? Color("appPrimary") : Color("appLabel")
    }

    var body: some View {
        ZStack {
            // Batang vertikal (badan "I")
            RoundedRectangle(cornerRadius: 6)
                .fill(arrowColor)
                .frame(width: 14, height: 110)
                .offset(y: 22)

            // Kepala panah (segitiga) di atas
            ArrowHeadShape()
                .fill(arrowColor)
                .frame(width: 64, height: 56)
                .offset(y: -46)

            // Ekor kecil di bawah sebagai aksen
            RoundedRectangle(cornerRadius: 3)
                .fill(arrowColor.opacity(0.6))
                .frame(width: 6, height: 24)
                .offset(y: 88)
        }
        .rotationEffect(.degrees(angleDegrees))
        .animation(.smooth(duration: 0.25), value: angleDegrees)
        .shadow(color: arrowColor.opacity(0.45), radius: 14, y: 4)
    }
}

struct ArrowHeadShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 32) {
            DirectionalArrowView(angleDegrees: 0, isOnTarget: true)
            DirectionalArrowView(angleDegrees: -45, isOnTarget: false)
        }
    }
}
