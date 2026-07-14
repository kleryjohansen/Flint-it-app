import SwiftUI
import MultipeerConnectivity

struct NearbyRadarView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel

    var body: some View {
        let ni = viewModel.niManager

        ZStack {
            VStack(spacing: 0) {
                // Header (Top bar with custom styled back button)
                HStack {
                    Button(action: {
                        withAnimation {
                            viewModel.appState = .home
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()

                // Radar & Arrow Visual
                VStack(spacing: 35) {
                    
                    VStack(spacing: 6) {
                        Text("Go find your mate!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(2)
                        
                        Text(viewModel.multipeerManager?.connectedPeer?.displayName ?? "Partner")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }

                    // Rotating Arrow / Signal View
                    ZStack {
                        // Concentric circles background
                        Circle()
                            .stroke(Color.flintRed.opacity(0.2), lineWidth: 1.5)
                            .frame(width: 250, height: 250)

                        Circle()
                            .stroke(Color.flintRed.opacity(0.1), lineWidth: 1)
                            .frame(width: 170, height: 170)

                        radarContent(ni: ni)
                    }

                    // Large Distance display: matches Screen 4 ("3m ahead")
                    distanceDisplay(ni: ni)
                }

                Spacer()
                
                // Bottom cancel button: matches Screen 4
                Button(action: {
                    withAnimation {
                        viewModel.fullCleanup()
                    }
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.flintRed)
                        .clipShape(Capsule())
                        .shadow(color: Color.flintRed.opacity(0.35), radius: 12, y: 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .flintVibrantBackground()
        .navigationBarBackButtonHidden(true)
        .onDisappear {
            // Cleanup only if not forming a room
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
                // Large Arrow pointing to partner
                Image(systemName: "arrow.up")
                    .font(.system(size: 72, weight: .black))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(ni.arrowAngleDegrees))
                    .animation(.smooth(duration: 0.25), value: ni.arrowAngleDegrees)
                    .shadow(color: Color.flintRed.opacity(0.5), radius: 10)
            } else if ni.peerIsOutOfRange {
                // Out of range Wifi slash icon
                Image(systemName: "wifi.slash")
                    .font(.system(size: 54))
                    .foregroundColor(.white.opacity(0.4))
            } else {
                // Directionless circle
                Image(systemName: "location.circle")
                    .font(.system(size: 54))
                    .foregroundColor(.white.opacity(0.4))
            }
        } else if let error = ni.errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundColor(Color.flintRed)
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(Color.flintRed.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .onTapGesture {
                viewModel.niManager.reset()
            }
        } else {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("Connecting...")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    @ViewBuilder
    private func distanceDisplay(ni: NearbyInteractionManager) -> some View {
        if ni.peerIsOutOfRange {
            Text("Partner out of range")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
        } else if let distance = ni.distance {
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.0f", distance))
                        .font(.system(size: 80, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("m")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Text("ahead")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

#Preview {
    NearbyRadarView()
        .environmentObject(iOSWorkoutViewModel())
}
