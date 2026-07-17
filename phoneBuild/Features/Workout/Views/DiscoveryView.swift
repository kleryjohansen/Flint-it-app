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
            // Soft white-to-coral background
            LinearGradient(
                colors: [Color.white, Color("appTertiary"), Color("appSecondary")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

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
            .tint(Color("appPrimary"))
            .toolbar(viewModel.appState == .home ? .visible : .hidden, for: .tabBar)
            .toolbarBackground(viewModel.appState == .home ? .visible : .hidden, for: .tabBar)
            .toolbarColorScheme(viewModel.appState == .home ? nil : .dark, for: .tabBar)

            // Bottom slide-up card when a peer is selected
            peerOverlayCard
        }
        .onChange(of: viewModel.appState) { newState in
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
        VStack {
            // Header
            HStack {
                if viewModel.appState == .searching {
                    Button(action: {
                        withAnimation {
                            viewModel.appState = .home
                            viewModel.multipeerManager?.stopSearching()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.title3.bold())
                            .foregroundColor(Color("appLabel").opacity(0.8))
                            .padding(10)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                }
                Spacer()

            if !watchSession.isWatchConnected {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.applewatch")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Watch Connection Required")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text("Please pair an Apple Watch and open the Flint-it app on it to start searching.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color.white.opacity(0.06))
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 16) {
                // Label di atas tombol flame
                Text(viewModel.appState == .home ? "Tap to find rival" : "Finding people nearby...")
                    .font(.title).bold()
                    .foregroundColor(Color("appLabel"))
                    .multilineTextAlignment(.center)

                ZStack {
                    let pulseStroke = (colorScheme == .light ? Color.flintRed : Color("appFlameHighlight"))

                    if viewModel.appState == .searching {
                        // Pulsing radar circles (stroke only — material breaks scaleAnimation)
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

                        // Concentric rings (static style) with liquid glass
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(Color.flintRed.opacity(0.08), lineWidth: 1)
                            )
                            .frame(width: 230, height: 230)

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
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .frame(width: 46, height: 46)
                                            .foregroundColor(Color("appPrimary"))
                                            .background(Circle().fill(Color("appBrandBackground")))
                                            .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))
                                            .shadow(color: Color("appPrimary").opacity(0.4), radius: 6)

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

                // Secondary info label
                VStack(spacing: 8) {
                    if let count = viewModel.multipeerManager?.foundPeers.count, count > 0 {
                        Text("\(count) peer(s) nearby")
                            .font(.subheadline)
                            .foregroundColor(Color("appSecondaryLabel"))
                    }

                    if showSearchSkip && viewModel.appState == .searching {
                        Button(action: {
                            withAnimation {
                                viewModel.skipConnectionAndGoToSetup()
                            }
                        }) {
                            Text("Skip to Setup (Solo)")
                                .font(.callout).bold()
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(Color("appPrimary"))
                                .clipShape(Capsule())
                                .shadow(color: Color("appPrimary").opacity(0.35), radius: 8)
                        }
                        .padding(.top, 8)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }

            Spacer()
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
