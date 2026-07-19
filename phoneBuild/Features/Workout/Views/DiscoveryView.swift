import SwiftUI
import MultipeerConnectivity

struct DiscoveryView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var pulseScale: CGFloat = 1.0
    @State private var outerPulseScale: CGFloat = 1.0
    @State private var selectedDiscoveryPeer: MCPeerID? = nil
    @State private var selectedWorkout: PastWorkout? = nil
    @State private var showSearchSkip = false
    @ObservedObject private var watchSession = WatchSessionManager.shared

    var body: some View {
        ZStack {
            // MARK: - Background
            Image("bgifhome")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Dark overlay + top/bottom gradient — HANYA saat .home
            if viewModel.appState == .home {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()

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
                    .frame(height: 280)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // Decorative red radial glow
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.flintRed.opacity(0.18),
                    Color.black.opacity(0)
                ]),
                center: .center,
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // MARK: - Foreground content
            VStack(spacing: 0) {
                topBar
                    .padding(.top, 60)

                Spacer(minLength: 16)

                centerHero

                Spacer(minLength: 16)

                bottomSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }

            // Bottom slide-up card when a peer is selected
            peerOverlayCard
        }
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .fullScreenCover(item: $selectedWorkout) { workout in
            HistoryDetailView(workout: workout)
                .environmentObject(viewModel)
        }
        .onChange(of: viewModel.appState) { _, newState in
            if newState == .searching {
                showSearchSkip = false
                pulseScale = 1.0
                outerPulseScale = 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    if viewModel.appState == .searching {
                        withAnimation { showSearchSkip = true }
                    }
                }
            } else {
                showSearchSkip = false
            }
        }
    }

    // MARK: - Top Bar (Watch pill + X close)

    private var topBar: some View {
        HStack {
            if viewModel.appState == .searching && watchSession.isWatchConnected {
                Button(action: {
                    withAnimation {
                        viewModel.appState = .home
                        viewModel.multipeerManager?.stopSearching()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.title3.bold())
                        .foregroundColor(.white.opacity(0.85))
                        .padding(10)
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }

            Spacer()

            if watchSession.isWatchConnected && viewModel.appState == .home {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color("appGreen"))
                        .frame(width: 8, height: 8)
                    Text("Watch is connected")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(Color.white.opacity(0.12))
                )
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Center Hero (Title + Radar)

    private var centerHero: some View {
        VStack(spacing: 24) {
            Text(viewModel.appState == .home ? "Tap to find rival" : "Finding people nearby...")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)

            ZStack {
                let pulseStroke = Color.flintRed

                if viewModel.appState == .searching {
                    Circle()
                        .stroke(pulseStroke.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 280, height: 280)
                        .scaleEffect(pulseScale)
                        .opacity(Double(2.0 - pulseScale))
                        .onAppear {
                            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                                pulseScale = 2.0
                            }
                        }

                    Circle()
                        .stroke(pulseStroke.opacity(0.15), lineWidth: 1)
                        .frame(width: 180, height: 180)
                        .scaleEffect(outerPulseScale)
                        .opacity(Double(2.0 - outerPulseScale))
                        .onAppear {
                            withAnimation(.easeOut(duration: 2.0).delay(0.5).repeatForever(autoreverses: false)) {
                                outerPulseScale = 2.0
                            }
                        }
                }

                // Static glass radar
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(Color.flintRed.opacity(0.08), lineWidth: 1)
                    )
                    .frame(width: 230, height: 230)

                // Found peers on radar
                if viewModel.appState == .searching,
                   let peers = viewModel.multipeerManager?.foundPeers {
                    ForEach(Array(peers.enumerated()), id: \.element.id) { index, peer in
                        let radius = CGFloat(140 + (index % 2) * 60)
                        let angle = Double(index) * 75.0 + 45.0
                        let xOffset = radius * CGFloat(cos(angle * .pi / 180.0))
                        let yOffset = radius * CGFloat(sin(angle * .pi / 180.0))

                        Button(action: {
                            withAnimation { selectedDiscoveryPeer = peer.id }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 46, height: 46)
                                    .foregroundColor(Color.flintRed)
                                    .background(Circle().fill(Color("appBrandBackground")))
                                    .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))
                                    .shadow(color: Color.flintRed.opacity(0.4), radius: 6)

                                Text(peer.displayName)
                                    .font(.caption2).bold()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color("appOverlayDim")))
                            }
                        }
                        .offset(x: xOffset, y: yOffset)
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                // Central glowing flame button
                Button(action: {
                    withAnimation {
                        if viewModel.appState == .home {
                            viewModel.appState = .searching
                            viewModel.multipeerManager?.startBrowsing()
                        } else {
                            viewModel.appState = .home
                            viewModel.multipeerManager?.stopSearching()
                            selectedDiscoveryPeer = nil
                        }
                    }
                }) {
                    Image("logoflamemiddle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 70)
                }
                .buttonStyle(FlameGlassButtonStyle())
            }
            .frame(height: 320)

            if let count = viewModel.multipeerManager?.foundPeers.count, count > 0 {
                Text("\(count) peer(s) nearby")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Bottom Section (Recent Activity)

    @ViewBuilder
    private var bottomSection: some View {
        if let latest = viewModel.pastWorkouts.first {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent activity")
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(0.5)

                Button {
                    selectedWorkout = latest
                } label: {
                    RecentActivityRow(workout: latest)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Peer Overlay Card

    @ViewBuilder
    private var peerOverlayCard: some View {
        if let peerId = selectedDiscoveryPeer,
           let peer = viewModel.multipeerManager?.foundPeers.first(where: { $0.id == peerId }) {

            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { selectedDiscoveryPeer = nil }
                }

            VStack {
                Spacer()

                VStack(spacing: 20) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)

                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 90)
                        .foregroundColor(Color.flintRed)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 3))
                        .padding(.top, 10)

                    Text(peer.displayName)
                        .font(.title2).bold()
                        .foregroundColor(.white)

                    Button(action: {
                        withAnimation {
                            selectedDiscoveryPeer = nil
                            viewModel.invite(peer: peer.id)
                        }
                    }) {
                        Text("Connect & Find")
                            .font(.callout).bold()
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
                .frame(maxWidth: .infinity)
                .flintGlassCard()
                .transition(.move(edge: .bottom))
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Recent Activity Row (compact)

struct RecentActivityRow: View {
    let workout: PastWorkout

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy · HH:mm"
        return formatter.string(from: workout.date)
    }

    private var titleText: String {
        if let partner = workout.partnerName {
            return "\(workout.type.rawValue) vs \(partner)"
        }
        return workout.type.rawValue
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.flintRed.opacity(0.18))
                    .frame(width: 44, height: 44)

                Image(systemName: workout.type.iconName)
                    .font(.subheadline.bold())
                    .foregroundColor(.flintRed)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(titleText)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            if let partner = workout.partnerName {
                Text("1")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Home Tab Container (Home + Profile)

struct HomeTabView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoveryView()
                .tag(0)
                .tabItem {
                    Label("Home", systemImage: "figure.run")
                }

            ProfileView()
                .environmentObject(viewModel)
                .tag(1)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(Color.flintRed)
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
    }
}

#Preview {
    HomeTabView()
        .environmentObject(iOSWorkoutViewModel())
}
