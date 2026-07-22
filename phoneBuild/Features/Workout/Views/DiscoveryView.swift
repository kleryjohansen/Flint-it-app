import SwiftUI
import MultipeerConnectivity

struct DiscoveryView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var pulseScale: CGFloat = 1.0
    @State private var outerPulseScale: CGFloat = 1.0
    @State private var selectedDiscoveryPeer: MCPeerID? = nil
    @State private var selectedTab = 0
    @State private var showSearchSkip = false
    @ObservedObject private var watchSession = WatchSessionManager.shared

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // ─── TAB 1: DISCOVER ───
                discoverTab
                    .tag(0)
                    .tabItem {
                        Label("Home", systemImage: "figure.run")
                    }

                // ─── TAB 2: PROFILE ───
                profileTab
                    .tag(1)
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
            }
            .tint(Color.flintRed)
            .toolbar(viewModel.appState == .home ? .visible : .hidden, for: .tabBar)
            .toolbarBackground(viewModel.appState == .home ? .visible : .hidden, for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)

            // Bottom slide-up card when a peer is selected
            peerOverlayCard
        }
        .onChange(of: viewModel.appState) { _, newState in
            if newState == .searching {
                showSearchSkip = false
                pulseScale = 1.0
                outerPulseScale = 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    if viewModel.appState == .searching {
                        withAnimation {
                            showSearchSkip = true
                        }
                    }
                }
            } else {
                showSearchSkip = false
            }
        }
    }

    // MARK: - Tab 1: Discover / Radar

    private var discoverTab: some View {
        ZStack {
            // Pure background image extending 100% full screen to all edges (including bottom tab bar)
            Image("bgifhome")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // Layer 1: Centered Content (Tap to find rival & Nearby button)
            VStack(spacing: 0) {
                // Spacer below top status pill
                Spacer()
                    .frame(height: 160)
                
                // Title Label
                Text(viewModel.appState == .home ? "Tap to find\nmatch buddy" : "Finding people nearby...")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.6), radius: 6, x: 0, y: 3)
                    .multilineTextAlignment(.center)
                
                Spacer(minLength: 16)

                ZStack {
                    let pulseStroke = Color.white.opacity(0.6)

                    if viewModel.appState == .searching {
                        // Pulsing radar circles
                        Circle()
                            .stroke(pulseStroke.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 280, height: 280)
                            .scaleEffect(pulseScale)
                            .opacity(Double(2.0 - pulseScale))
                            .onAppear {
                                withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                                    pulseScale = 2.0
                                }
                            }

                        Circle()
                            .stroke(pulseStroke.opacity(0.25), lineWidth: 1)
                            .frame(width: 180, height: 180)
                            .scaleEffect(outerPulseScale)
                            .opacity(Double(2.0 - outerPulseScale))
                            .onAppear {
                                withAnimation(.easeOut(duration: 2.0).delay(0.5).repeatForever(autoreverses: false)) {
                                    outerPulseScale = 2.0
                                }
                            }

                        // Found peers on radar
                        if let peers = viewModel.multipeerManager?.foundPeers {
                            ForEach(Array(peers.enumerated()), id: \.element.id) { index, peer in
                                let radius = CGFloat(140 + (index % 2) * 60)
                                let angle = Double(index) * 75.0 + 45.0
                                let xOffset = radius * CGFloat(cos(angle * .pi / 180.0))
                                let yOffset = radius * CGFloat(sin(angle * .pi / 180.0))

                                Button(action: {
                                    withAnimation {
                                        selectedDiscoveryPeer = peer.id
                                    }
                                }) {
                                    VStack(spacing: 4) {
                                        if let base64 = peer.profileImageBase64,
                                           let imgData = Data(base64Encoded: base64),
                                           let uiImg = UIImage(data: imgData) {
                                            Image(uiImage: uiImg)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 46, height: 46)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))
                                                .shadow(color: Color.flintRed.opacity(0.4), radius: 6)
                                        } else {
                                            Image(systemName: "person.crop.circle.fill")
                                                .resizable()
                                                .frame(width: 46, height: 46)
                                                .foregroundColor(Color.flintRed)
                                                .background(Circle().fill(Color.black))
                                                .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))
                                                .shadow(color: Color.flintRed.opacity(0.4), radius: 6)
                                        }

                                        Text(peer.displayName)
                                            .font(.caption2).bold()
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(.ultraThinMaterial))
                                    }
                                }
                                .offset(x: xOffset, y: yOffset)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }

                    // Native Apple Liquid Glass Button containing "nearbybutton" asset
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
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
                        ZStack {
                            // Native Liquid Glass Outer Ring Layer
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 170, height: 170)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .glassEffect(.regular.interactive(), in: .circle)
                                .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 8)
                            
                            // Nearby Button Image Asset
                            Image("nearbybutton")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(height: 220)
                
                // Solo button directly below search/radar button
                Button(action: {
                    withAnimation {
                        viewModel.skipConnectionAndGoToSetup()
                    }
                }) {
                    Text("Skip to Setup (Solo)")
                        .font(.callout).bold()
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(Color.flintRed)
                        .clipShape(Capsule())
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .shadow(color: Color.flintRed.opacity(0.4), radius: 8)
                }
                .padding(.top, 16)
                
                Spacer(minLength: 16)

                // Secondary info label
                VStack(spacing: 8) {
                    if let count = viewModel.multipeerManager?.foundPeers.count, count > 0 {
                        Text("\(count) peer(s) nearby")
                            .font(.subheadline.bold())
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            // Layer 2: Top Status Pill (Watch Connected indicator) aligned independently to top
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
                .padding(.top, 96)

                Spacer()
            }
        }
    }

    // MARK: - Tab 2: Profile

    private var profileTab: some View {
        VStack {
            // Header
            HStack {
                Text("Profile & History")
                    .font(.title3).bold()
                    .foregroundColor(Color("appLabel"))
                    .padding(.top, 8)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            ProfileView()
                .environmentObject(viewModel)
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
                    // Drag indicator
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)

                    // Avatar
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 90)
                        .foregroundColor(Color("appPrimary"))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 3))
                        .padding(.top, 10)

                    // Peer Name
                    Text(peer.displayName)
                        .font(.title2).bold()
                        .foregroundColor(.white)

                    // Connect & Find Button
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
                            .glassEffect(.regular.interactive(), in: .capsule)
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

#Preview {
    DiscoveryView()
        .environmentObject(iOSWorkoutViewModel())
}
