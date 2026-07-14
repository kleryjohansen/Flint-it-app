import SwiftUI
import MultipeerConnectivity

struct NearbyRadarView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel

    var body: some View {
        let ni = viewModel.niManager

        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {

                // Partner name
                Text(viewModel.multipeerManager?.connectedPeer?.displayName ?? "Partner")
                    .font(.title2)
                    .foregroundColor(.orange)

                // Arrow + Radar Ring
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                        .frame(width: 280, height: 280)

                    Circle()
                        .stroke(Color.orange.opacity(0.15), lineWidth: 1)
                        .frame(width: 180, height: 180)

                    radarContent(ni: ni)
                }

                // Distance
                distanceDisplay(ni: ni)

                // Room formation hint
                if let distance = ni.distance, distance < 2.0 {
                    Text("Close enough to start!")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(20)
                }

                Spacer()
            }
            .padding(.top, 60)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    // Navigasi balik — cleanup dilakukan di onDisappear
                    viewModel.appState = .home
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.orange)
                }
            }
        }
        .onChange(of: viewModel.currentRoom) { _, newRoom in
            if newRoom != nil {
                print("[Radar] Room formed, staying connected")
            }
        }
        .onDisappear {
            // Cleanup HANYA kalau tidak sedang forming room
            if viewModel.currentRoom == nil {
                viewModel.fullCleanup()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func radarContent(ni: NearbyInteractionManager) -> some View {
        if ni.isSessionActive {
            if ni.direction != nil {
                // Arrow pointing to partner (UWB available)
                Image(systemName: "arrow.up")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(.orange)
                    .rotationEffect(.degrees(ni.arrowAngleDegrees))
                    .animation(.smooth(duration: 0.3), value: ni.arrowAngleDegrees)
            } else if ni.peerIsOutOfRange {
                // Out of range
                Image(systemName: "wifi.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.orange.opacity(0.5))
            } else {
                // Session active but no direction (device has no UWB chip)
                Image(systemName: "location.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange.opacity(0.5))
            }
        } else if let error = ni.errorMessage {
            // Error — tap to retry
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.orange.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .onTapGesture {
                viewModel.niManager.reset()
            }
        } else {
            // Waiting for token exchange to complete
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.orange)
                Text("Connecting...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func distanceDisplay(ni: NearbyInteractionManager) -> some View {
        if ni.peerIsOutOfRange {
            Text("Partner out of range")
                .font(.headline)
                .foregroundColor(.orange.opacity(0.7))
        } else if let distance = ni.distance {
            VStack(spacing: 4) {
                Text(String(format: "%.1f", distance))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("meters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NearbyRadarView()
        .environmentObject(iOSWorkoutViewModel())
}
