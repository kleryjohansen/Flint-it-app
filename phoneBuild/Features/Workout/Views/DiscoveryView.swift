import SwiftUI
import MultipeerConnectivity

struct DiscoveryView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var watchSession = WatchSessionManager.shared
    @State private var pulseScale: CGFloat = 1.0
    @State private var outerPulseScale: CGFloat = 1.0
    @State private var selectedDiscoveryPeer: MCPeerID? = nil
    @State private var selectedTab: String = "Tab 1" // "Tab 1" (Home/Search) or "Tab 2" (Profile/History)
    @State private var showSearchSkip = false
    
    var body: some View {
        ZStack {
            VStack {
                // Header (Top bar)
                HStack {
                    if selectedTab == "Tab 1" {
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
                                    .background(Circle().fill(Color("appGlassWhite")))
                            }
                        }
                    } else {
                        // Profile Header
                        Text("Profile & History")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color("appLabel"))
                            .padding(.top, 8)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                if selectedTab == "Tab 1" {
                    // ─── TAB 1: WORKOUT SEARCH / RADAR ───
                    
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
                    
                    Spacer()
                    
                    VStack(spacing: 40) {
                        ZStack {
                            if viewModel.appState == .searching {
                                // Pulsing radar circles
                                Circle()
                                    .stroke(Color.flintRed.opacity(0.3), lineWidth: 1.5)
                                    .frame(width: 280, height: 280)
                                    .scaleEffect(pulseScale)
                                    .opacity(Double(2.0 - pulseScale))
                                    .onAppear {
                                        withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                                            pulseScale = 2.0
                                        }
                                    }
                                
                                Circle()
                                    .stroke(Color.flintRed.opacity(0.15), lineWidth: 1)
                                    .frame(width: 180, height: 180)
                                    .scaleEffect(outerPulseScale)
                                    .opacity(Double(2.0 - outerPulseScale))
                                    .onAppear {
                                        withAnimation(.easeOut(duration: 2.0).delay(0.5).repeatForever(autoreverses: false)) {
                                            outerPulseScale = 2.0
                                        }
                                    }
                                
                                // Concentric rings (static style)
                                Circle()
                                    .stroke(Color.flintRed.opacity(0.08), lineWidth: 1)
                                    .frame(width: 230, height: 230)
                                
                                // Place found peers directly on the concentric radar rings
                                if let peers = viewModel.multipeerManager?.foundPeers {
                                    ForEach(Array(peers.enumerated()), id: \.element.id) { index, peer in
                                        let radius = CGFloat(100 + (index % 2) * 50)
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
                                                    .foregroundColor(.orange)
                                                    .background(Circle().fill(Color.black))
                                                    .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))
                                                    .shadow(color: .orange.opacity(0.4), radius: 6)
                                                
                                                Text(peer.displayName)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Capsule().fill(Color.black.opacity(0.6)))
                                            }
                                        }
                                        .disabled(viewModel.multipeerManager?.pendingInvitingPeer != nil)
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
                                ZStack {
                                    let isWatchConnected = watchSession.isWatchConnected
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                gradient: Gradient(colors: [Color.flintRed, Color.flintRed.opacity(0.85)]),
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: 46
                                            )
                                        )
                                        .frame(width: 92, height: 92)
                                        .opacity(isWatchConnected ? 1.0 : 0.4)
                                        .shadow(color: Color.flintRed.opacity(isWatchConnected ? 0.65 : 0.0), radius: 18)
                                    
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(.white)
                                        .opacity(isWatchConnected ? 1.0 : 0.4)
                                }
                            }
                            .disabled(!watchSession.isWatchConnected)
                        }
                        .frame(height: 300)
                        
                        // Main description label
                        VStack(spacing: 8) {
                            Text(viewModel.appState == .home ? "Tap to find mates" : "Finding people nearby...")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(Color("appLabel"))
                            
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
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 20)
                                        .background(Color.orange)
                                        .clipShape(Capsule())
                                        .shadow(color: Color.orange.opacity(0.35), radius: 8)
                                }
                                .padding(.top, 8)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    
                    Spacer()
                } else {
                    // ─── TAB 2: PROFILE & HISTORY ───
                    ProfileView()
                        .environmentObject(viewModel)
                }
                
                // Bottom control (Host/Join capsule control styled exactly like screenshot)
                if viewModel.appState == .home {
                    HStack(spacing: 0) {
                        // Tab 1
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedTab = "Tab 1"
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "rhombus.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(colorScheme == .light ? Color.blue : Color.flintRed)
                                Text("Tab 1")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(colorScheme == .light ? Color.blue : Color.flintRed)
                            }
                            .frame(width: 72, height: 48)
                            .background(
                                Group {
                                    if selectedTab == "Tab 1" {
                                        Capsule()
                                            .fill(colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.12))
                                    }
                                }
                            )
                        }
                        
                        // Tab 2
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedTab = "Tab 2"
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(colorScheme == .light ? Color.black : Color.white)
                                Text("Tab 2")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(colorScheme == .light ? Color.black : Color.white)
                            }
                            .frame(width: 72, height: 48)
                            .background(
                                Group {
                                    if selectedTab == "Tab 2" {
                                        Capsule()
                                            .fill(colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.12))
                                    }
                                }
                            )
                        }
                    }
                    .padding(4)
                    .background(Capsule().fill(Color.white.opacity(colorScheme == .light ? 0.6 : 0.08)))
                    .overlay(Capsule().stroke(Color.white.opacity(colorScheme == .light ? 0.3 : 0.05), lineWidth: 1))
                    .shadow(color: Color.black.opacity(colorScheme == .light ? 0.05 : 0.1), radius: 10, y: 4)
                    .padding(.bottom, 24)
                } else {
                    Spacer().frame(height: 53)
                }
            }
            
            // Bottom slide-up card when a peer is selected (Screen 3 style)
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
                            .foregroundColor(.orange)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 3))
                            .padding(.top, 10)
                        
                        // Peer Name
                        Text(peer.displayName)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        // Connect & Find Button
                        Button(action: {
                            withAnimation {
                                selectedDiscoveryPeer = nil
                                viewModel.invite(peer: peer.id)
                            }
                        }) {
                            Text("Connect & Find")
                                .font(.system(size: 16, weight: .bold))
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
        .flintVibrantBackground()
        .navigationBarBackButtonHidden(true)
        .onChange(of: viewModel.appState) { newState in
            if newState == .searching {
                showSearchSkip = false
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
}

#Preview {
    DiscoveryView()
        .environmentObject(iOSWorkoutViewModel())
}
