import SwiftUI
import UIKit
import MultipeerConnectivity

struct IdentifiablePeer: Identifiable {
    var id: MCPeerID { peerID }
    let peerID: MCPeerID
}

struct ContentView: View {
    @StateObject private var viewModel = iOSWorkoutViewModel()

    var body: some View {
        ZStack { 
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
            .alert(item: $viewModel.activeAlert) { alertType in
                switch alertType {
                case .distanceDisconnect:
                    return Alert(
                        title: Text("Lost connection"),
                        message: Text("you left the match because of disconnected from nearby"),
                        dismissButton: .default(Text("OK")) {
                            viewModel.activeAlert = nil
                        }
                    )
                case .rivalLeft:
                    return Alert(
                        title: Text("Match Cancelled"),
                        message: Text("your rival has left the room"),
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
                case .rematchPrompt:
                    return Alert(
                        title: Text("Rematch Request"),
                        message: Text("\(viewModel.primaryPartnerName) asked you for a rematch!"),
                        primaryButton: .default(Text("Accept")) {
                            viewModel.acceptRematchRequest()
                        },
                        secondaryButton: .cancel(Text("Decline")) {
                            viewModel.activeAlert = nil
                        }
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

    private var challenge: WorkoutChallenge? {
        viewModel.selectedChallenge ?? viewModel.receivedChallenge
    }

    private var isDistanceChallenge: Bool {
        challenge?.metricType == "distance" ||
        challenge?.sport == .running ||
        challenge?.sport == .cycling ||
        challenge?.sport == .swimming
    }

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

    private var distanceText: String {
        if liveDistanceMeters >= 1000 {
            return String(format: "%.2f km", liveDistanceMeters / 1000.0)
        } else {
            return String(format: "%.0f m", liveDistanceMeters)
        }
    }

    var body: some View {
        ZStack {
            switch challenge?.sport {
            case .running:
                Image("bgifrun")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            case .cycling:
                Image("bgifcycling")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            case .swimming:
                Image("bgifswim")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            default:
                Image("bgLobby")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.black.opacity(0.65), .black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)

                Spacer()

                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: watchSession.isWatchConnected ? "applewatch.radiowaves.left.and.right" : "exclamationmark.applewatch")
                                .font(.system(size: 14))
                                .foregroundColor(watchSession.isWatchConnected ? Color.green : Color.orange)
                            
                            Text(watchSession.isWatchConnected ? "Watch is connected" : "Please connect to Apple Watch")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                        Spacer()
                    }
                    .padding(.top, 80)
                    .padding(.bottom, 16)
                }
                
                VStack(spacing: 8) {
                    if let ch = challenge {
                        Text("\(ch.challengeName) • \(ch.sport.rawValue)")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.primary)
                    } else {
                        Text("Active Match")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    
                    VStack(spacing: 4) {
                        if let ch = challenge {
                            Text("Goal: \(String(format: "%.0f", ch.goalValue))\(isDistanceChallenge ? " km" : "")")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Fastest to finish wins")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 32)
                }
                
                HStack {
                    Text(viewModel.countdownText)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(16)
                .glassEffect(in: .rect(cornerRadius: 24))
                .padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.flintRed)
                                .frame(width: 44, height: 44)
                            Image(systemName: "figure.run")
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        Text("Distance")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("\(distanceText)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassEffect(in: .rect(cornerRadius: 24))
                .padding(.horizontal, 16)
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.flintRed)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "powermeter")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                            Text("Pace")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(viewModel.avgPaceText)
                            .font(.title.weight(.bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassEffect(in: .rect(cornerRadius: 24))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.flintRed)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "heart.fill")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                            Text("Heartrate")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("\(Int(liveHR)) Bpm")
                            .font(.title.weight(.bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassEffect(in: .rect(cornerRadius: 24))
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                // Multi-Player HUD (VS Progress)
                VStack(spacing: 12) {
                    // Player 1 (You)
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                .frame(width: 20, height: 20)
                            Text("1")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 6)
                                
                                Capsule()
                                    .fill(Color.flintRed)
                                    .frame(width: geometry.size.width * CGFloat(viewModel.localProgress), height: 6)
                            }
                        }
                        .frame(height: 6)
                        
                        Text("\(Int(viewModel.localProgress * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 38, alignment: .trailing)
                    }
                    
                    // RIVAL: Menampilkan salah satu opponent (Primary Peer / pertama di dictionary)
                    if let rivalPeer = viewModel.primaryConnectedPeer,
                       let rivalProgress = viewModel.partnerProgress[rivalPeer] {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                    .frame(width: 20, height: 20)
                                Text("2")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 6)
                                    
                                    Capsule()
                                        .fill(Color.flintRed)
                                        .frame(width: geometry.size.width * CGFloat(rivalProgress), height: 6)
                                }
                            }
                            .frame(height: 6)
                            
                            Text(viewModel.primaryPartnerName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                                .frame(maxWidth: 80, alignment: .leading)
                            
                            Text("\(Int(rivalProgress * 100))%")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 38, alignment: .trailing)
                        }
                    }
                }
                .padding(24)
                .background(Color.black.opacity(0.6))
                .cornerRadius(24)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            if viewModel.countdownSeconds >= 0 {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                
                VStack {
                    ZStack {
                        Circle()
                            .fill(Color.flintRed.opacity(0.12))
                            .frame(width: 140, height: 140)
                            .blur(radius: 12)
                        
                        Text(viewModel.countdownSeconds == 0 ? "GO!" : "\(viewModel.countdownSeconds)")
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .foregroundColor(viewModel.countdownSeconds == 0 ? .white : .flintRed)
                            .shadow(color: Color.flintRed.opacity(0.4), radius: 10, y: 5)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.countdownSeconds)
                    }
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Results View

struct ResultsView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @State private var showLeaderboard = false
    
    private var challenge: WorkoutChallenge? {
        viewModel.selectedChallenge ?? viewModel.receivedChallenge
    }
    
    private var ownName: String {
        UserDefaults.standard.string(forKey: "savedUsername") ?? "You"
    }

    var body: some View {
        ZStack {
            if viewModel.workoutResult == .victory || viewModel.workoutResult == .solo {
                Image("winBG")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                Image("loseBG")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
            
            VStack {
                Spacer()
                
                VStack(spacing: 24) {
                    VStack(spacing: -16) {
                        ZStack {
                            if viewModel.workoutResult == .victory || viewModel.workoutResult == .solo {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white)
                                    .padding(24)
                                    .glassEffect(.regular.tint(Color("appPrimary")))
                                    .shadow(color: Color("appPrimary").opacity(1), radius: 32)
                            } else {
                                Image(systemName: "hands.clap.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                                    .padding(24)
                                    .glassEffect(.regular.tint(.black))
                                    .shadow(color: .black.opacity(0.6), radius: 32)
                            }
                        }
                    }
                    
                    VStack(spacing: 12) {
                        if viewModel.workoutResult == .victory || viewModel.workoutResult == .solo {
                            Text("Congratulations!")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(.primary)
                            
                            Text("You've just won")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Try again buddy!")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(.primary)
                            
                            Text("Nice try on")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        if let ch = challenge {
                            Text("\(ch.challengeName) • \(ch.sport.rawValue)")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.vertical, 8)
                        
                        HStack(spacing: 20) {
                            metricItem(
                                title: "Distance",
                                value: String(format: "%.1f", challenge?.metricType == "distance" ? viewModel.localDistance : (viewModel.localDistance / 1000.0)),
                                unit: challenge?.metricType == "distance" ? "m" : "km",
                                icon: "figure.run"
                            )
                            
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .frame(height: 40)
                            
                            metricItem(
                                title: "Time",
                                value: viewModel.countdownText,
                                unit: "min",
                                icon: "stopwatch"
                            )
                        }
                    }
                    
                    VStack(spacing: 12) {
                        if viewModel.primaryConnectedPeer != nil && viewModel.workoutResult != .solo {
                            Button(action: {
                                withAnimation {
                                    showLeaderboard = true
                                }
                            }) {
                                Text("View Statistics")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .glassEffect(.regular, in: .capsule)
                                    .shadow(color: Color.black.opacity(0.2), radius: 10, y: 5)
                            }
                            
                            Button(action: {
                                viewModel.sendRematchRequest()
                            }) {
                                Text("Rematch")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.flintRed)
                                    .clipShape(Capsule())
                                    .shadow(color: Color.flintRed.opacity(0.3), radius: 10, y: 5)
                            }
                        }
                        
                        Button(action: {
                            withAnimation {
                                viewModel.fullCleanup()
                            }
                        }) {
                            Text("Done")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 8)
                    }
                    .padding(.top, 16)
                }
                .padding(32)
                .background(
                    ZStack {
                        if viewModel.workoutResult == .victory || viewModel.workoutResult == .solo {
                            Image("winCardBg")
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image("loseCardBg")
                                .resizable()
                                .scaledToFill()
                        }
                        Color(red: 0.1, green: 0.1, blue: 0.1).opacity(0.65)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 30, y: 15)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardSheet(ownName: ownName)
                .environmentObject(viewModel)
        }
    }
    
    private func metricItem(title: String, value: String, unit: String, icon: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.5))
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Leaderboard Sheet
struct LeaderboardSheet: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @Environment(\.dismiss) var dismiss
    let ownName: String
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    let ownVal = viewModel.localDistance
                    let rivalID = viewModel.primaryConnectedPeer
                    let rivalVal = rivalID != nil ? (viewModel.partnerDistance[rivalID!] ?? 0.0) : 0.0
                    let rivalName = viewModel.primaryPartnerName
                    
                    let weWon = viewModel.workoutResult == .victory || viewModel.workoutResult == .solo
                    
                    participantRow(
                        rank: weWon ? "1" : "2",
                        name: "\(ownName) (You)",
                        value: "\(String(format: "%.0f", ownVal))m",
                        isWinner: weWon
                    )
                    
                    if rivalID != nil {
                        participantRow(
                            rank: weWon ? "2" : "1",
                            name: rivalName,
                            value: "\(String(format: "%.0f", rivalVal))m",
                            isWinner: !weWon
                        )
                    }
                    
                    Spacer()
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
            }
            .navigationTitle("Final Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color.flintRed)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func participantRow(rank: String, name: String, value: String, isWinner: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isWinner ? Color.flintRed : Color.white.opacity(0.1))
                    .frame(width: 40, height: 40)
                Text(rank)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isWinner ? .white : .white.opacity(0.6))
            }
            
            Text(name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isWinner ? Color.flintRed.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
        )
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
