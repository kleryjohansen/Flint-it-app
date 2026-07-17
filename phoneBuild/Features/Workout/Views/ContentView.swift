import SwiftUI
import MultipeerConnectivity

struct IdentifiablePeer: Identifiable {
    var id: MCPeerID { peerID }
    let peerID: MCPeerID
}

struct ContentView: View {
    @StateObject private var viewModel = iOSWorkoutViewModel()

    var body: some View {
        Group {
            switch viewModel.appState {
            case .home, .searching:
                DiscoveryView()

            case .navigating:
                NearbyRadarView()

            case .room:
                RoomFormedView()

            case .workoutSetup:
                WorkoutSetupView()

            case .syncing:
                ChallengeWaitingView()

            case .foundPartner:
                Group { Text("Found Partner") }
                    .flintVibrantBackground()

            case .activeWorkout:
                ActiveWorkoutView()
                    .environmentObject(viewModel)

            case .results:
                ResultsView()
                    .environmentObject(viewModel)
            @unknown default:
                EmptyView()
            }
        }
        .environmentObject(viewModel)
        .sheet(item: Binding<IdentifiablePeer?>(
            get: {
                if let peer = viewModel.multipeerManager?.pendingInvitingPeer {
                    return IdentifiablePeer(peerID: peer)
                }
                return nil
            },
            set: { _ in }
        )) { _ in
            InviteReceivedView().environmentObject(viewModel)
        }
        .sheet(item: Binding<IdentifiableChallenge?>(
            get: {
                if let challenge = viewModel.receivedChallenge {
                    return IdentifiableChallenge(challenge: challenge)
                }
                return nil
            },
            set: { _ in }
        )) { challengeObj in
            ChallengeReceivedView(challenge: challengeObj.challenge)
                .environmentObject(viewModel)
        }
    }
}

// MARK: - Active Workout View

struct ActiveWorkoutView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @ObservedObject private var watchSession = WatchSessionManager.shared
    @State private var heartPulse = false

    // Challenge determines what metric to show — read from challenge directly, NOT from Watch state
    private var challenge: WorkoutChallenge? {
        viewModel.selectedChallenge ?? viewModel.receivedChallenge
    }

    // True jika challenge adalah distance (Running/Cycling)
    private var isDistanceChallenge: Bool {
        challenge?.metricType == "distance" ||
        challenge?.sport == .running ||
        challenge?.sport == .cycling ||
        challenge?.sport == .swimming
    }

    // Live values dari Watch via WCSession
    private var liveHR: Double {
        watchSession.workoutState["heartRate"] as? Double ?? 0.0
    }
    private var liveDistanceMeters: Double {
        watchSession.workoutState["distance"] as? Double ?? 0.0
    }
    private var liveCalories: Double {
        watchSession.workoutState["calories"] as? Double ?? 0.0
    }
    private var watchConnected: Bool {
        watchSession.workoutState["status"] as? String == "active"
    }

    // Format jarak: meter atau km
    private var distanceText: String {
        if liveDistanceMeters >= 1000 {
            return String(format: "%.2f km", liveDistanceMeters / 1000.0)
        } else {
            return String(format: "%.0f m", liveDistanceMeters)
        }
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Watch connection indicator & floating competitive HUD
                HStack(spacing: 12) {
                    Circle()
                        .fill(watchConnected ? Color("appGreen") : Color("appGray").opacity(0.5))
                        .frame(width: 8, height: 8)
                    
                    Text(UserDefaults.standard.string(forKey: "savedUsername") ?? "You")
                        .font(.caption2.bold())
                        .foregroundColor(.white.opacity(0.8))
                    
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(Color.flintRed)
                            .frame(width: 70 * CGFloat(viewModel.localProgress), height: 6)
                    }
                    .frame(width: 70)
                    
                    Text("VS")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Color("appOrange"))
                    
                    if viewModel.multipeerManager?.connectedPeer != nil {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(Color("appSecondaryLabel"))
                                .frame(width: 70 * CGFloat(viewModel.partnerProgress), height: 6)
                        }
                        .frame(width: 70)
                        
                        Text(viewModel.currentRoom?.partnerName ?? "Partner")
                            .font(.caption2.bold())
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .padding(.top, 12)

                if let ch = challenge {
                    Text(ch.challengeName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color("appOrange"))
                        .textCase(.uppercase)
                }

                // ── Elapsed Time ──
                VStack(spacing: 2) {
                    Text(viewModel.countdownText)
                        .font(.system(size: 72, weight: .medium, design: .default))
                        .monospacedDigit()
                        .foregroundColor(.white)
                }
                .padding(.top, 10)
                
                Divider()
                    .background(Color.white.opacity(0.15))
                    .padding(.horizontal, 32)
                
                // ── Giant Speed/Pace Center Metric (Strava Style) ──
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", viewModel.localSpeed).replacingOccurrences(of: ".", with: ","))
                        .font(.system(size: 96, weight: .bold))
                        .foregroundColor(.white)
                    Text("Speed (km/h)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
                
                Divider()
                    .background(Color.white.opacity(0.15))
                    .padding(.horizontal, 32)
                
                // ── Sub metrics 2x2 Grid (Strava Style) ──
                VStack(spacing: 24) {
                    HStack {
                        // Distance
                        VStack(spacing: 4) {
                            Text(String(format: "%.2f", liveDistanceMeters / 1000.0).replacingOccurrences(of: ".", with: ","))
                                .font(.system(size: 38, weight: .bold))
                                .foregroundColor(.white)
                            Text("Distance (km)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 1, height: 50)
                        
                        // Elevation Gain
                        VStack(spacing: 4) {
                            Text(String(format: "%.0f", viewModel.localElevation))
                                .font(.system(size: 38, weight: .bold))
                                .foregroundColor(.white)
                            Text("Elev. gain (m)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 8)
                    
                    HStack {
                        // Steps
                        VStack(spacing: 4) {
                            Text(String(format: "%.0f", viewModel.localSteps))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            Text("Steps")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 1, height: 50)
                        
                        // Pace
                        VStack(spacing: 4) {
                            Text(viewModel.avgPaceText)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            Text("Avg Pace")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
                
                // Partner live HUD (if multiplayer)
                if viewModel.multipeerManager?.connectedPeer != nil {
                    VStack(spacing: 6) {
                        Text("\(viewModel.currentRoom?.partnerName ?? "Partner")'s Live Stats")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Color("appOrange"))
                            .textCase(.uppercase)
                        
                        HStack(spacing: 16) {
                            Text(String(format: "Dist: %.2f km", viewModel.partnerDistance / 1000.0))
                            Text("•")
                            Text(String(format: "Steps: %.0f", viewModel.partnerSteps))
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

// MARK: - Reusable Metric Card

struct MetricCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let unit: String
    let accentColor: Color
    @Binding var pulse: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.title3.bold())
                    .foregroundColor(iconColor)
                    .scaleEffect(pulse ? 1.15 : 1.0)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title2, design: .default).bold())
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
                Text(unit)
                    .font(.caption.bold())
                    .foregroundColor(Color("appSecondaryLabel"))
                    .textCase(.uppercase)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .flintGlassCard()
        .padding(.horizontal, 24)
    }
}

// MARK: - Results View

struct ResultsView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel

    var body: some View {
        ZStack {
            Color.clear
                .flintVibrantBackground()

            VStack(spacing: 24) {
                Image(systemName: "trophy.fill")
                    .font(.largeTitle)
                    .foregroundColor(Color("appYellow"))

                Text("Workout Complete!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)

                VStack(spacing: 12) {
                    ResultRow(icon: "clock.fill", color: Color("appOrange"), label: "Duration", value: viewModel.countdownText)
                    ResultRow(icon: "heart.fill", color: Color("appRed"), label: "Avg Heart Rate", value: viewModel.heartRate > 0 ? "\(Int(viewModel.heartRate)) BPM" : "---")
                    ResultRow(icon: "flame.fill", color: Color("appOrange"), label: "Calories", value: String(format: "%.1f kcal", viewModel.watchCalories))
                }
                .padding(20)
                .flintGlassCard()
                .padding(.horizontal, 24)

                Button("Back to Home") {
                    viewModel.fullCleanup()
                }
                .buttonStyle(FlintPrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .padding(.top, 40)
        }
    }
}

struct ResultRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
            Text(label)
                .font(.body)
                .foregroundColor(Color("appSecondaryLabel"))
            Spacer()
            Text(value)
                .font(.body.bold())
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

#Preview("ContentView") {
    ContentView()
}

#Preview("ActiveWorkoutView") {
    ActiveWorkoutView()
        .environmentObject(iOSWorkoutViewModel())
}

#Preview("ResultsView") {
    ResultsView()
        .environmentObject(iOSWorkoutViewModel())
}
