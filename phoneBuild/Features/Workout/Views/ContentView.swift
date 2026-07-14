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
                Group {
                    Text("Found Partner")
                }
                .flintVibrantBackground()
                
            case .activeWorkout:
                Group {
                    Text("Active Workout Dashboard (Ready to Track)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    if let challenge = viewModel.selectedChallenge ?? viewModel.receivedChallenge {
                        Text("Active Challenge: \(challenge.challengeName)")
                            .font(.headline)
                            .foregroundColor(.orange)
                            .padding(.top, 8)
                        
                        Text("Tracking: \(challenge.metricType == "distance" ? "Distance (UWB)" : "Calories Burned (Apple Watch)")")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 4)
                    }
                    
                    Button("Finish Workout") {
                        viewModel.appState = .results
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .padding(.top, 40)
                }
                .flintVibrantBackground()
                
            case .results:
                Group {
                    VStack(spacing: 20) {
                        Text("Workout Completed!")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                        
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.yellow)
                        
                        Button("Back to Home") {
                            viewModel.fullCleanup()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .padding(.top, 20)
                    }
                }
                .flintVibrantBackground()
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
            InviteReceivedView()
                .environmentObject(viewModel)
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

#Preview {
    ContentView()
}
