import SwiftUI
import MultipeerConnectivity

struct IdentifiablePeer: Identifiable {
    var id: MCPeerID { peerID }
    let peerID: MCPeerID
}

struct ContentView: View {
    @StateObject private var viewModel = iOSWorkoutViewModel()

    var body: some View {
        ZStack { // I add it back
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
                case .rematchPrompt:
                    return Alert(
                        title: Text("Rematch Request"),
                        message: Text("\(viewModel.multipeerManager?.connectedPeer?.displayName ?? "Opponent") asked you for a rematch!"),
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
            // Dynamic Background based on sport
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
                Image("bgifhome")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
            
            // Dark overlay
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            // Top & bottom vertical gradient for text readability
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

            VStack(spacing: 16) {
                // Top HUD: Challenge name & subtitle
                Circle()
                    .fill(Color.green)
                    .frame(width: 28, height: 28)
                    .padding(.top, 80)
                VStack(spacing: 4) {
                    if let ch = challenge {
                        Text("\(ch.challengeName) • \(ch.sport.rawValue)")
                            .font(.largeTitle .weight(.bold))
                            .foregroundStyle(.primary)
                        
                        Text("Fastest to finish \(String(format: "%.0f", ch.goalValue))\(isDistanceChallenge ? "km" : "") wins")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    } else {
                        Text("Workout • Running")
                            .font(.largeTitle .weight(.bold))
                            .foregroundStyle(.primary)
                        Text("Fastest to finish wins")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 32)
                
                // 1. Time Display Card
                HStack {
                    Text(viewModel.countdownText)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(16)
//                .background(.ultraThinMaterial)
//                .cornerRadius(20)
                .glassEffect(in: .rect(cornerRadius: 24))
                .padding(.horizontal, 16)
                
                // 2. Distance Card
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
                
                // 3. Pace and Heartrate (Bottom Row)
                HStack(spacing: 12) {
                    // Pace Card
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
                                .font(.headline.weight( .semibold))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(viewModel.avgPaceText)
                            .font(.title.weight(.bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .glassEffect(in: .rect(cornerRadius: 24))
                    
                    // Heartrate Card
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
                                .font(.headline.weight( .semibold))
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
                                .foregroundStyle(.secondary)
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
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .glassEffect(in: .rect(cornerRadius: 24))
                .padding(.horizontal, 24)
                .padding(.bottom, 70)
            }
            
                        // Countdown Overlay
            if viewModel.countdownSeconds >= 0 {
                ZStack {
                    // Dynamic Background based on sport
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
                        Image("bgifhome")
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea()
                    }
                    
                    // Dark overlay
                    Color.black.opacity(0.65)
                        .ignoresSafeArea()

                    // Top & bottom vertical gradient for text readability
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
    @State private var showLeaderboard = false
    
    // Active challenge
    private var challenge: WorkoutChallenge? {
        viewModel.selectedChallenge ?? viewModel.receivedChallenge
    }
    
    private var ownName: String {
        UserDefaults.standard.string(forKey: "savedUsername") ?? "You"
    }
    
    private var ownProfileImage: UIImage? {
        if let data = UserDefaults.standard.data(forKey: "savedProfileImageData") {
            return UIImage(data: data)
        }
        return nil
    }
    
    var body: some View {
        ZStack {
            // Win or Lose Background
            Image(viewModel.workoutResult == .victory || viewModel.workoutResult == .solo ? "winBackground" : "loseBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            Color.black.opacity(0.65)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Details
                VStack(spacing: 4) {
                    if let ch = challenge {
                        Text("\(ch.challengeName) • \(ch.sport.rawValue)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("Workout Complete")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text(Date(), style: .date)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, 60)
                
                Spacer()
                
                if !showLeaderboard {
                    // Card View: Trophy or Clapping Hands
                    Button(action: {
                        withAnimation(.spring()) {
                            showLeaderboard = true
                        }
                    }) {
                        VStack(spacing: 24) {
                            // Circular Badge with rays background
                            ZStack {
                                Image(viewModel.workoutResult == .victory || viewModel.workoutResult == .solo ? "winBackground" : "loseBackground")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .opacity(0.85)
                                
                                // Central trophy or clapping hands icon
                                ZStack {
                                    Circle()
                                        .fill(Color("appPrimary"))
                                        .frame(width: 80, height: 80)
                                        .shadow(color: Color("appPrimary").opacity(0.4), radius: 8)
                                    
                                    if viewModel.workoutResult == .victory || viewModel.workoutResult == .solo {
                                        Image(systemName: "trophy.fill")
                                            .font(.system(size: 36))
                                            .foregroundColor(.white)
                                    } else {
                                        Image(systemName: "hands.clap.fill")
                                            .font(.system(size: 36))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .frame(height: 200)
                            
                            VStack(spacing: 6) {
                                if viewModel.workoutResult == .victory || viewModel.workoutResult == .solo {
                                    Text("Congratulations!")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("You've just won")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.6))
                                } else {
                                    Text("Try again buddy!")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("Nice try on")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                
                                Text(challenge?.challengeName ?? "1km sprint • Run")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color("appPrimary"))
                            }
                            .padding(.bottom, 20)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Swipe/Tap indicator
                    VStack(spacing: 6) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Tap the card above")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 48)
                    
                } else {
                    // Leaderboard / Pod View + Rematch Buttons
                    VStack(spacing: 32) {
                        HStack(spacing: 24) {
                            if viewModel.workoutResult == .victory || viewModel.workoutResult == .solo {
                                PlayerResultPod(
                                    rank: "①",
                                    name: ownName,
                                    time: viewModel.countdownText,
                                    image: ownProfileImage
                                )
                                
                                if viewModel.multipeerManager?.connectedPeer != nil {
                                    let partnerName = viewModel.multipeerManager?.connectedPeer?.displayName ?? "Partner"
                                    let partnerSecs = viewModel.elapsedSeconds + 7
                                    let pMin = partnerSecs / 60
                                    let pSec = partnerSecs % 60
                                    let partnerTimeStr = String(format: "%02d:%02d", pMin, pSec)
                                    PlayerResultPod(
                                        rank: "②",
                                        name: partnerName,
                                        time: partnerTimeStr,
                                        image: nil
                                    )
                                }
                            } else {
                                let partnerName = viewModel.multipeerManager?.connectedPeer?.displayName ?? "Partner"
                                PlayerResultPod(
                                    rank: "①",
                                    name: partnerName,
                                    time: viewModel.countdownText,
                                    image: nil
                                )
                                
                                let ownSecs = viewModel.elapsedSeconds + 12
                                let oMin = ownSecs / 60
                                let oSec = ownSecs % 60
                                let ownTimeStr = String(format: "%02d:%02d", oMin, oSec)
                                PlayerResultPod(
                                    rank: "②",
                                    name: ownName,
                                    time: ownTimeStr,
                                    image: ownProfileImage
                                )
                            }
                        }
                        
                        VStack(spacing: 16) {
                            if viewModel.multipeerManager?.connectedPeer != nil {
                                Button(action: {
                                    viewModel.sendRematchRequest()
                                }) {
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
                            
                            Button(action: {
                                viewModel.fullCleanup()
                            }) {
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
                if let img = image {
                    Image(uiImage: img)
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
                        .fill(rank == "①" ? Color.flintRed : Color.white.opacity(0.18))
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
