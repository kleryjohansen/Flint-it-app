import SwiftUI

/// Adaptive particle ring yang intensitasnya ditentukan oleh jarak ke partner.
/// - 10m ke atas: partikel renggang, sedikit, melebar (mencari).
/// - 4m ke bawah: partikel meledak banyak, ring menyempit ke pusat (terkunci/mendekat).
struct ParticleRingView: View {
    let distance: Double? // dalam meter, nil = tak diketahui
    @State private var rotation: Double = 0
    @State private var pulse: CGFloat = 1.0

    private let maxDistance: Double = 10.0
    private let minDistance: Double = 4.0
    private let maxParticleCount: Int = 120
    private let minParticleCount: Int = 24

    // MARK: - Derived values (0 = jauh, 1 = dekat)

    /// 0.0 = jauh / tidak terkunci, 1.0 = sangat dekat (≤4m)
    private var proximityFactor: Double {
        guard let d = distance else { return 0.0 }
        let clamped = min(max(d, minDistance), maxDistance)
        // Normalisasi: 10m -> 0, 4m -> 1
        return 1.0 - ((clamped - minDistance) / (maxDistance - minDistance))
    }

    private var particleCount: Int {
        let raw = Double(minParticleCount) + proximityFactor * Double(maxParticleCount - minParticleCount)
        return Int(raw.rounded())
    }

    /// Radius efektif: saat jauh melebar, saat dekat menyempit ke pusat
    private var ringRadius: CGFloat {
        let baseFar: CGFloat = 130
        let baseNear: CGFloat = 55
        let factor = CGFloat(proximityFactor)
        return baseFar + (baseNear - baseFar) * factor
    }

    private var isLocked: Bool {
        guard let d = distance else { return false }
        return d <= minDistance
    }

    var body: some View {
        ZStack {
            // Inner core glow — muncul hanya saat sudah dekat
            if isLocked {
                Circle()
                    .fill(Color.red.opacity(0.22))
                    .frame(width: 90, height: 90)
                    .scaleEffect(pulse * 1.1)
                    .blur(radius: 10)
            }

            ForEach(0..<particleCount, id: \.self) { index in
                let angle = Double(index) / Double(particleCount) * 2 * .pi
                // Randomness mengecil saat dekat (lebih presisi)
                let jitterRange: ClosedRange<CGFloat> = isLocked ? -3...3 : -22...22
                let randomOffset = CGFloat.random(in: jitterRange)
                let actualRadius = ringRadius + randomOffset

                let x = cos(angle) * actualRadius
                let y = sin(angle) * actualRadius

                // Ukuran partikel membesar saat dekat
                let sizeRange: ClosedRange<CGFloat> = isLocked ? 4...8 : 2...5
                let size = CGFloat.random(in: sizeRange)
                let opacity = Double.random(in: 0.45...0.95)

                Circle()
                    .fill(
                        isLocked
                        ? Color.red.opacity(opacity)
                        : Color.white.opacity(opacity)
                    )
                    .frame(width: size, height: size)
                    .position(x: 150 + x, y: 150 + y)
                    .scaleEffect(pulse + CGFloat.random(in: -0.05...0.05))
            }
        }
        .frame(width: 300, height: 300)
        .rotationEffect(.degrees(rotation))
        .animation(.easeInOut(duration: 0.4), value: proximityFactor)
        .animation(.easeInOut(duration: 0.4), value: isLocked)
        .onAppear {
            withAnimation(.linear(duration: 12.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = 1.06
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 24) {
            Text("10m").foregroundColor(.white)
            ParticleRingView(distance: 10.0)
            Text("5m").foregroundColor(.white)
            ParticleRingView(distance: 5.0)
            Text("4m (locked)").foregroundColor(.white)
            ParticleRingView(distance: 3.0)
        }
    }
}
