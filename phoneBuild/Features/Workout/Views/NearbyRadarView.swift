import SwiftUI
import MultipeerConnectivity

struct NearbyRadarView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @State private var showSkipButton = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0.0

    private var showArrow: Bool {
        let ni = viewModel.niManager
        let currentDistance = ni.distance ?? .infinity
        return ni.direction != nil && currentDistance <= 10.0
    }

    private var directionalGuidance: String {
        let ni = viewModel.niManager
        guard ni.isSessionActive else { return "Connecting..." }

        if showArrow {
            let angle = ni.arrowAngleDegrees
            if angle < -18 {
                return "Turn Left ↺"
            } else if angle > 18 {
                return "Turn Right ↻"
            } else {
                return "Ahead 🎯"
            }
        } else {
            return "Walk around slowly"
        }
    }
    
    private var isOnTarget: Bool {
        let ni = viewModel.niManager
        guard ni.isSessionActive && showArrow else { return false }
        return abs(ni.arrowAngleDegrees) <= 18
    }

    var body: some View {
        let ni = viewModel.niManager

        ZStack {
            VStack(spacing: 0) {
                // Header (Top bar with back button)
                HStack {
                    Button(action: {
                        withAnimation {
                            viewModel.appState = .home
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .foregroundColor(Color("appLabel"))
                            .padding(10)
                            .background(Circle().fill(Color("appGlassWhite")))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()

                // Radar & Rotating Precision Arrow (Find My style)
                VStack(spacing: 30) {
                    
                    VStack(spacing: 6) {
                        Text("FINDING PARTNER")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(Color("appSecondaryLabel"))
                            .tracking(2)
                        
                        Text(viewModel.multipeerManager?.connectedPeer?.displayName ?? "Partner")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(Color("appLabel"))
                    }

                    // ZStack containing the Find My style precision radar
                    ZStack {
                        // Pulsing outer halo when on target
                        if isOnTarget {
                            Circle()
                                .fill(Color("appPrimary").opacity(0.12))
                                .frame(width: 290, height: 290)
                                .scaleEffect(pulseScale)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                        pulseScale = 1.15
                                    }
                                }
                        } else {
                            Circle()
                                .fill(Color("appPrimary").opacity(0.04))
                                .frame(width: 290, height: 290)
                        }

                        // Concentric circles background
                        Circle()
                            .stroke(isOnTarget ? Color("appPrimary").opacity(0.3) : Color("appGlassBorder"), lineWidth: 2)
                            .frame(width: 260, height: 260)

                        Circle()
                            .stroke(isOnTarget ? Color("appPrimary").opacity(0.15) : Color("appGlassBorder").opacity(0.5), lineWidth: 1.5)
                            .frame(width: 180, height: 180)

                        // Central navigation card
                        Circle()
                            .fill(Color("appGlassWhite"))
                            .frame(width: 140, height: 140)
                            .shadow(color: Color("appGlassShadow").opacity(0.15), radius: 15)

                        // Rotating Arrow with haptic/color feedback
                        radarContent(ni: ni)
                    }
                    .frame(height: 300)

                    // Text Guidance: "Turn Left", "Turn Right", "Ahead"
                    Text(directionalGuidance)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(isOnTarget ? Color("appPrimary") : Color("appLabel"))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isOnTarget ? Color("appPrimary").opacity(0.12) : Color.clear)
                        )
                        .animation(.easeInOut(duration: 0.2), value: directionalGuidance)

                    // Distance text display
                    distanceDisplay(ni: ni)
                }

                Spacer()
                
                // Action Buttons at the Bottom
                VStack(spacing: 12) {
                    if showSkipButton {
                        Button(action: {
                            withAnimation {
                                viewModel.skipProximityAndGoToRoom()
                            }
                        }) {
                            Text("Skip Proximity Check")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.orange)
                                .clipShape(Capsule())
                                .shadow(color: Color.orange.opacity(0.35), radius: 12, y: 6)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
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
                            .background(Color("appPrimary"))
                            .clipShape(Capsule())
                            .shadow(color: Color("appPrimary").opacity(0.3), radius: 10, y: 5)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .flintVibrantBackground()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Delay 5 seconds before showing the skip button for testing
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation {
                    showSkipButton = true
                }
            }
        }
        .onDisappear {
            if viewModel.currentRoom == nil {
                viewModel.fullCleanup()
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func radarContent(ni: NearbyInteractionManager) -> some View {
        if ni.isSessionActive {
            if showArrow {
                // Custom directional arrow (lebih besar & jelas dari SF Symbol)
                DirectionalArrowView(
                    angleDegrees: ni.arrowAngleDegrees,
                    isOnTarget: isOnTarget
                )
            } else if ni.peerIsOutOfRange {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 48))
                    .foregroundColor(Color("appSecondaryLabel").opacity(0.6))
            } else {
                ParticleRingView(distance: ni.distance)
            }
        } else if let error = ni.errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundColor(Color("appPrimary"))
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(Color("appPrimary").opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .onTapGesture {
                viewModel.niManager.reset()
            }
        } else {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(Color("appLabel"))
                Text("Connecting...")
                    .font(.system(size: 12))
                    .foregroundColor(Color("appSecondaryLabel"))
            }
        }
    }

    @ViewBuilder
    private func distanceDisplay(ni: NearbyInteractionManager) -> some View {
        if ni.peerIsOutOfRange {
            Text("Partner out of range")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color("appSecondaryLabel"))
        } else if let distance = ni.distance {
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", distance))
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundColor(Color("appLabel"))
                    Text("m")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Color("appSecondaryLabel"))
                }
            }
        }
    }
}

#Preview {
    NearbyRadarView()
        .environmentObject(iOSWorkoutViewModel())
}
