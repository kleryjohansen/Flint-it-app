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
            Color.clear
                .flintVibrantBackground()

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        // Watch connection indicator
                        Circle()
                            .fill(watchConnected ? Color("appGreen") : Color("appGray").opacity(0.5))
                            .frame(width: 8, height: 8)
                        Text(watchConnected ? "Watch Connected" : "Waiting for Watch...")
                            .font(.caption2.bold())
                            .foregroundColor(watchConnected ? Color("appGreen") : Color("appGray"))
                            .textCase(.uppercase)
                        Spacer()
                    }
                    .padding(.horizontal, 24)

                    if let ch = challenge {
                        Text(ch.challengeName)
                            .font(.subheadline.bold())
                            .foregroundColor(Color("appSecondaryLabel"))
                    }

                    // Elapsed timer
                    Text(viewModel.countdownText)
                        .font(.system(.largeTitle, design: .default, weight: .bold))
                        .fontWidth(.compressed)
                        .monospacedDigit()
                        .foregroundColor(.primary)
                        .shadow(color: Color.flintRed.opacity(0.4), radius: 20, y: 10)
                }

                // ── Heart Rate Card ──
                MetricCard(
                    icon: "heart.fill",
                    iconColor: Color("appRed"),
                    value: liveHR > 0 ? "\(Int(liveHR))" : "---",
                    unit: "BPM",
                    accentColor: Color("appRed"),
                    pulse: $heartPulse
                )
                .onAppear { heartPulse = true }

                // ── Distance or Calories Card ──
                if isDistanceChallenge {
                    MetricCard(
                        icon: challenge?.sport == .cycling ? "figure.outdoor.cycle" : "figure.run",
                        iconColor: Color("appPrimary"),
                        value: distanceText,
                        unit: "Distance",
                        accentColor: Color("appPrimary"),
                        pulse: .constant(false)
                    )
                } else {
                    MetricCard(
                        icon: "flame.fill",
                        iconColor: Color("appOrange"),
                        value: String(format: "%.1f", liveCalories),
                        unit: "kcal burned",
                        accentColor: Color("appOrange"),
                        pulse: .constant(false)
                    )
                }

                Spacer()

                // Finish button
                Button(action: { viewModel.endWorkout() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                        Text("Finish Workout")
                    }
                }
                .buttonStyle(FlintPrimaryButtonStyle())
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
