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
                    VStack(spacing: 24) {
                        Text("ACTIVE WORKOUT")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(2)
                        
                        Text(viewModel.countdownText)
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                        
                        if let challenge = viewModel.selectedChallenge ?? viewModel.receivedChallenge {
                            Text(challenge.challengeName)
                                .font(.title3.bold())
                                .foregroundColor(.orange)
                            
                            VStack(spacing: 16) {
                                // Live heart rate from Watch
                                HStack(spacing: 12) {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.red)
                                        .font(.title2)
                                    Text(viewModel.heartRate > 0 ? "\(Int(viewModel.heartRate)) BPM" : "-- BPM")
                                        .font(.title2.bold())
                                        .foregroundColor(.white)
                                }
                                
                                // Live metrics based on challenge type
                                if challenge.metricType == "distance" {
                                    // UWB Distance tracking
                                    if let distance = viewModel.niManager.distance {
                                        Text(String(format: "%.1f meters", distance))
                                            .font(.title.bold())
                                            .foregroundColor(.white)
                                    } else {
                                        Text("Searching for partner...")
                                            .font(.headline)
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                } else {
                                    // Calories Burned (Apple Watch)
                                    VStack(spacing: 4) {
                                        Text(String(format: "%.1f", viewModel.watchCalories))
                                            .font(.system(size: 48, weight: .bold, design: .rounded))
                                            .foregroundColor(.orange)
                                        Text("kcal burned")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .flintGlassCard()
                        }
                        
                        Button("Finish Workout") {
                            viewModel.endWorkout()
                        }
                        .buttonStyle(FlintPrimaryButtonStyle(isWhite: false))
                        .padding(.top, 20)
                    }
                    .padding(24)
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
