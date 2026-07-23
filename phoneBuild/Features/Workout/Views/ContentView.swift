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

    var body: some View {
        ZStack {
            Image(viewModel.workoutResult == .victory || viewModel.workoutResult == .solo ? "winBG" : "loseBG")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    if let ch = challenge {
                        Text("\(ch.challengeName) • \(ch.sport.rawValue)")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Workout Complete")
                            .font(.title2.bold())
                            .foregroundStyle(.primary)
                    }

                    Text(Date(), style: .date)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 80)

                Spacer()

                if !showLeaderboard {
                    Button {
                        withAnimation(.spring()) {
                            showLeaderboard = true
                        }
                    } label: {
                        VStack(spacing: 24) {
                            ZStack {
                                Image(viewModel.workoutResult == .victory || viewModel.workoutResult == .solo ? "winCardBg" : "loseCardBg")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .cornerRadius(32)

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

                                Text(challenge?.challengeName ?? "Workout Complete")
                                    .font(.title2.bold())
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 32)
                        .background(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .fill(Color.black.opacity(0.8))
                        )
                        .glassEffect(in: .rect(cornerRadius: 32))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    Spacer()

                    VStack(spacing: 6) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Tap the card above")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 48)

                    Spacer()
                } else {
                    VStack(spacing: 32) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 24) {
                                ForEach(Array(viewModel.allContestantResults.enumerated()), id: \.element.name) { index, contestant in
                                    let minutes = contestant.time / 60
                                    let seconds = contestant.time % 60
                                    let time = String(format: "%02d:%02d", minutes, seconds)

                                    PlayerResultPod(
                                        rank: "\(index + 1)",
                                        name: contestant.name,
                                        time: time,
                                        image: contestant.image
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        VStack(spacing: 16) {
                            if viewModel.primaryConnectedPeer != nil {
                                Button {
                                    viewModel.sendRematchRequest()
                                } label: {
                                    Text("Rematch")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color.flintRed)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            Capsule()
                                                .stroke(Color.flintRed, lineWidth: 2)
                                        )
                                }
                            }

                            Button {
                                viewModel.fullCleanup()
                            } label: {
                                Text("Back to home")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.flintRed)
                                    .clipShape(Capsule())
                                    .shadow(color: Color.flintRed.opacity(0.3), radius: 10, y: 5)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 48)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
    }
}

struct PlayerResultPod: View {
    let rank: String
    let name: String
    let time: String
    let image: UIImage?

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 80, height: 80)

                        Image(systemName: "person.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                ZStack {
                    Circle()
                        .fill(rank == "1" ? Color.flintRed : Color.white.opacity(0.18))
                        .frame(width: 24, height: 24)

                    Text(rank)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(y: 10)
            }
            .padding(.bottom, 6)

            Text(name)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(time)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(width: 110)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(20)
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
