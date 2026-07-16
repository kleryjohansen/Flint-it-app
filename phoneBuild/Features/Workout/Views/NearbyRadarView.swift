import SwiftUI
import MultipeerConnectivity

struct NearbyRadarView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @State private var showSkipButton = false

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
                            .foregroundColor(.primary)
                            .padding(10)
                            .background(Circle().fill(.ultraThinMaterial))
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
                            .font(.subheadline).bold()
                            .foregroundColor(Color("appSecondaryLabel"))
                            .tracking(2)

                        Text(viewModel.multipeerManager?.connectedPeer?.displayName ?? "Partner")
                            .font(.title3).bold()
                            .foregroundColor(.primary)
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

                // Action Buttons at the Bottom
                VStack(spacing: 12) {
                    if showSkipButton {
                        // Skip Proximity Button (Appears after 5 seconds to bypass Nearby Interaction)
                        Button(action: {
                            withAnimation {
                                viewModel.skipProximityAndGoToRoom()
                            }
                        }) {
                            Text("Skip Proximity Check")
                                .font(.callout).bold()
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color("appPrimary"))
                                .clipShape(Capsule())
                                .shadow(color: Color("appPrimary").opacity(0.35), radius: 12, y: 6)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Cancel button
                    Button(action: {
                        withAnimation {
                            viewModel.fullCleanup()
                        }
                    }) {
                        Text("Cancel")
                            .font(.callout).bold()
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.flintRed)
                            .clipShape(Capsule())
                            .shadow(color: Color.flintRed.opacity(0.35), radius: 12, y: 6)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .flintVibrantBackground()
        .onAppear {
            // Delay 5 seconds before showing the skip button for testing
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation {
                    showSkipButton = true
                }
            }
        }
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
                    .font(.largeTitle).fontWeight(.black)
                    .foregroundColor(.primary)
                    .rotationEffect(.degrees(ni.arrowAngleDegrees))
                    .animation(.smooth(duration: 0.25), value: ni.arrowAngleDegrees)
                    .shadow(color: Color.flintRed.opacity(0.5), radius: 10)
            } else if ni.peerIsOutOfRange {
                // Out of range Wifi slash icon
                Image(systemName: "wifi.slash")
                    .font(.largeTitle)
                    .foregroundColor(Color("appGlassWhite"))
            } else {
                // Directionless circle
                Image(systemName: "location.circle")
                    .font(.largeTitle)
                    .foregroundColor(Color("appGlassWhite"))
            }
        } else if let error = ni.errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundColor(Color.flintRed)
                Text(error)
                    .font(.caption)
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
                    .font(.caption)
                    .foregroundColor(Color("appSecondaryLabel"))
            }
        }
    }

    @ViewBuilder
    private func distanceDisplay(ni: NearbyInteractionManager) -> some View {
        if ni.peerIsOutOfRange {
            Text("Partner out of range")
                .font(.callout).bold()
                .foregroundColor(Color("appSecondaryLabel"))
        } else if let distance = ni.distance {
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.0f", distance))
                        .font(.system(.largeTitle, design: .default)).fontWeight(.black).monospacedDigit()
                        .foregroundColor(.primary)
                    Text("m")
                        .font(.title).bold()
                        .foregroundColor(.primary)
                }

                Text("ahead")
                    .font(.title3).bold()
                    .foregroundColor(Color("appSecondaryLabel"))
            }
        }
    }
}

#Preview {
    NearbyRadarView()
        .environmentObject(iOSWorkoutViewModel())
}
