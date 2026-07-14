import SwiftUI
import MultipeerConnectivity

struct DiscoveryView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @State private var pulseScale: CGFloat = 1.0
    @State private var outerPulseScale: CGFloat = 1.0
    @State private var selectedDiscoveryPeer: MCPeerID? = nil
    @State private var selectedTab: String = "Host" // "Host" | "Join" to match Screen 1 bottom pill
    
    var body: some View {
        ZStack {
            VStack {
                // Header (Top bar)
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
                                .foregroundColor(.white.opacity(0.8))
                                .padding(10)
                                .background(Circle().fill(Color.white.opacity(0.1)))
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                // Central radar/flame button
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
                            
                            // Place found peers directly on the concentric radar rings to match Screen 2/3
                            if let peers = viewModel.multipeerManager?.foundPeers {
                                ForEach(Array(peers.enumerated()), id: \.element.id) { index, peer in
                                    let radius = CGFloat(100 + (index % 2) * 50)
                                    let angle = Double(index) * 75.0 + 45.0 // distributes them around the circle
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
                                    .shadow(color: Color.flintRed.opacity(0.65), radius: 18)
                                
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(height: 300)
                    
                    // Main description label
                    VStack(spacing: 8) {
                        Text(viewModel.appState == .home ? "Tap to find mates" : "Finding people nearby...")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        if let count = viewModel.multipeerManager?.foundPeers.count, count > 0 {
                            Text("\(count) peer(s) nearby")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
                
                // Bottom control (Host/Join capsule control from Screen 1)
                if viewModel.appState == .home {
                    HStack(spacing: 0) {
                        Button(action: {
                            withAnimation { selectedTab = "Host" }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "rhombus.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(selectedTab == "Host" ? .white : .white.opacity(0.4))
                                Text("Host")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(selectedTab == "Host" ? .white : .white.opacity(0.6))
                            }
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(selectedTab == "Host" ? Capsule().fill(Color.flintRed) : Capsule().fill(Color.clear))
                        }
                        
                        Button(action: {
                            withAnimation { selectedTab = "Join" }
                        }) {
                            HStack(spacing: 6) {
                                Circle()
                                    .frame(width: 6, height: 6)
                                    .foregroundColor(selectedTab == "Join" ? .white : .white.opacity(0.4))
                                Text("Join")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(selectedTab == "Join" ? .white : .white.opacity(0.6))
                            }
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(selectedTab == "Join" ? Capsule().fill(Color.flintRed) : Capsule().fill(Color.clear))
                        }
                    }
                    .padding(3)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.05), lineWidth: 1))
                    .frame(width: 170)
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
    }
}

#Preview {
    DiscoveryView()
        .environmentObject(iOSWorkoutViewModel())
}
