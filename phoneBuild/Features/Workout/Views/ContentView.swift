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
                MatchConfirmationView()
                
            case .activeWorkout:
                ActiveWorkoutView()
                    .environmentObject(viewModel)
                
            case .results:
                ResultsView()
                    .environmentObject(viewModel)
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
            .alert(item: $viewModel.activeAlert) { alertType in
                switch alertType {
                case .distanceDisconnect:
                    return Alert(
                        title: Text("Koneksi Terputus"),
                        message: Text("ur left the match because off disconected from nearby"),
                        dismissButton: .default(Text("OK")) {
                            viewModel.activeAlert = nil
                        }
                    )
                case .rivalLeft:
                    return Alert(
                        title: Text("Match Cancelled"),
                        message: Text("your rival has leave the room"),
                        dismissButton: .default(Text("OK")) {
                            viewModel.activeAlert = nil
                        }
                    )
                case .leaveConfirmation:
                    return Alert(
                        title: Text("Leave Lobby"),
                        message: Text("Are you sure you want to leave the room?"),
                        primaryButton: .destructive(Text("Leave")) {
                            withAnimation {
                                viewModel.leaveLobby()
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
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
            Image("bgifhome")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Top HUD: Challenge name & subtitle
                VStack(spacing: 4) {
                    if let ch = challenge {
                        Text("\(ch.challengeName) • \(ch.sport.rawValue)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Fastest to finish \(String(format: "%.0f", ch.goalValue))\(isDistanceChallenge ? "km" : "") wins")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        Text("Workout • Running")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Text("Fastest to finish wins")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.top, 40)
                
                // 1. Time Display Card
                HStack {
                    Text(viewModel.countdownText)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding(.horizontal, 24)
                
                // 2. Distance Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.flintRed)
                                .frame(width: 32, height: 32)
                            Image(systemName: "figure.run")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("Distance")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text("\(distanceText)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding(.horizontal, 24)
                
                // 3. Pace and Heartrate (Bottom Row)
                HStack(spacing: 16) {
                    // Pace Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.flintRed)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "speedometer")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("Pace")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Text(viewModel.avgPaceText)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(20)
                    
                    // Heartrate Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.flintRed)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("Heartrate")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Text("\(Int(liveHR)) Bpm")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(20)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // 4. Multi-Player HUD (VS Progress)
                VStack(spacing: 16) {
                    // Player 1 (You)
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                .frame(width: 24, height: 24)
                            Text("1")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 8)
                                
                                Capsule()
                                    .fill(Color.flintRed)
                                    .frame(width: geometry.size.width * CGFloat(viewModel.localProgress), height: 8)
                            }
                        }
                        .frame(height: 8)
                        
                        Text("\(Int(viewModel.localProgress * 100))%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    // Player 2 (Partner)
                    if viewModel.multipeerManager?.connectedPeer != nil {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                    .frame(width: 24, height: 24)
                                Text("2")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 8)
                                    
                                    Capsule()
                                        .fill(Color.flintRed)
                                        .frame(width: geometry.size.width * CGFloat(viewModel.partnerProgress), height: 8)
                                }
                            }
                            .frame(height: 8)
                            
                            Text("\(Int(viewModel.partnerProgress * 100))%")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(24)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            
                        // Countdown Overlay
            if viewModel.countdownSeconds >= 0 {
                ZStack {
                    Color.black.opacity(0.92)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        Text(viewModel.countdownSeconds == 0 ? "GO!" : "\(viewModel.countdownSeconds)")
                            .font(.system(size: viewModel.countdownSeconds == 0 ? 110 : 130, weight: .black, design: .rounded))
                            .foregroundColor(Color.flintRed)
                            .transition(.scale.combined(with: .opacity))
                            .id(viewModel.countdownSeconds)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.countdownSeconds)
                        
                        Text(viewModel.countdownSeconds == 0 ? "START RIVALRY" : "GET READY")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .tracking(2)
                    }
                }
            }
            
            // Distance Warning Banner (3-8m)
            if viewModel.showDistanceWarning {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                        Text("oops jangan jauh2 dari rival kamu")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.orange)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.3), radius: 6)
                    .padding(.top, 70)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: viewModel.showDistanceWarning)
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
