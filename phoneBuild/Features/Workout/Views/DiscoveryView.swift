import SwiftUI
import MultipeerConnectivity

struct DiscoveryView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @State private var pulseScale: CGFloat = 1.0
    @State private var outerPulseScale: CGFloat = 1.0
    
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
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                // Central radar/flame button
                VStack(spacing: 30) {
                    ZStack {
                        if viewModel.appState == .searching {
                            // Pulsing radar circles
                            Circle()
                                .stroke(Color.flintRed.opacity(0.3), lineWidth: 2)
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
                        }
                        
                        // Central flame button
                        Button(action: {
                            withAnimation {
                                if viewModel.appState == .home {
                                    viewModel.appState = .searching
                                    viewModel.multipeerManager?.startBrowsing()
                                } else {
                                    viewModel.appState = .home
                                    viewModel.multipeerManager?.stopSearching()
                                }
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [Color.flintRed, Color.flintRed.opacity(0.8)]),
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 50
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                    .shadow(color: Color.flintRed.opacity(0.6), radius: 20)
                                
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(height: 300)
                    
                    // Main description label
                    VStack(spacing: 8) {
                        Text(viewModel.appState == .home ? "Tap to find mates" : "Finding people nearby...")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        if let count = viewModel.multipeerManager?.foundPeers.count, count > 0 {
                            Text("\(count) partner(s) found")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                
                Spacer()
                
                // Found peers list (only when searching and peers are discovered)
                if viewModel.appState == .searching, let peers = viewModel.multipeerManager?.foundPeers, !peers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(peers) { peer in
                                VStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.orange)
                                    
                                    VStack(spacing: 4) {
                                        Text(peer.displayName)
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                        
                                        if viewModel.multipeerManager?.invitedPeer == peer.id {
                                            Text("Inviting...")
                                                .font(.system(size: 10))
                                                .foregroundColor(.yellow)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(20)
                                .onTapGesture {
                                    viewModel.invite(peer: peer.id)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 30)
                    }
                    .frame(height: 140)
                } else {
                    Spacer().frame(height: 140)
                }
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
