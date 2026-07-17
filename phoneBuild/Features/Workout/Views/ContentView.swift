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
        challenge?.sport == .cycling
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
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.10, green: 0.04, blue: 0.20)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 4) {
                    HStack {
                        // Watch connection indicator
                        Circle()
                            .fill(watchConnected ? Color.green : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                        Text(watchConnected ? "Watch Connected" : "Waiting for Watch...")
                            .font(.caption2)
                            .foregroundColor(watchConnected ? .green : .gray)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    
                    if let ch = challenge {
                        Text(ch.challengeName.uppercased())
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                            .tracking(2)
                    }
                    
                    // Elapsed timer
                    Text(viewModel.countdownText)
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .shadow(color: .orange.opacity(0.3), radius: 10)
                }
                
                // ── Heart Rate Card ──
                MetricCard(
                    icon: "heart.fill",
                    iconColor: .red,
                    value: liveHR > 0 ? "\(Int(liveHR))" : "---",
                    unit: "BPM",
                    accentColor: .red,
                    pulse: $heartPulse
                )
                .onAppear { heartPulse = true }
                
                // ── Distance or Calories Card ──
                if isDistanceChallenge {
                    MetricCard(
                        icon: challenge?.sport == .cycling ? "figure.outdoor.cycle" : "figure.run",
                        iconColor: .blue,
                        value: distanceText,
                        unit: "Distance",
                        accentColor: .blue,
                        pulse: .constant(false)
                    )
                } else {
                    MetricCard(
                        icon: "flame.fill",
                        iconColor: .orange,
                        value: String(format: "%.1f", liveCalories),
                        unit: "kcal burned",
                        accentColor: .orange,
                        pulse: .constant(false)
                    )
                }
                
                Spacer()
                
                // Finish button
                Button(action: { viewModel.endWorkout() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                        Text("Finish Workout")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.red.opacity(0.85), .red],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .padding(.top, 12)
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
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(iconColor)
                .scaleEffect(pulse ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: value)
                Text(unit)
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(accentColor.opacity(0.35), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Results View

struct ResultsView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.12), Color(red: 0.10, green: 0.04, blue: 0.20)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.yellow)
                
                Text("Workout Complete!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    ResultRow(icon: "clock.fill", color: .orange, label: "Duration", value: viewModel.countdownText)
                    ResultRow(icon: "heart.fill", color: .red, label: "Avg Heart Rate", value: viewModel.heartRate > 0 ? "\(Int(viewModel.heartRate)) BPM" : "---")
                    ResultRow(icon: "flame.fill", color: .orange, label: "Calories", value: String(format: "%.1f kcal", viewModel.watchCalories))
                }
                .padding(20)
                .background(Color.white.opacity(0.07))
                .cornerRadius(20)
                .padding(.horizontal, 24)
                
                Button("Back to Home") {
                    viewModel.fullCleanup()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
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
            Image(systemName: icon).foregroundColor(color)
            Text(label).foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value).foregroundColor(.white).bold()
        }
    }
}

#Preview {
    ContentView()
}
