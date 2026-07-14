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
                
            case .foundPartner:
                Group {
                    Text("Found Partner")
                }
                .flintVibrantBackground()
                
            case .workoutSetup:
                Group {
                    Text("Workout Setup")
                }
                .flintVibrantBackground()
                
            case .syncing:
                Group {
                    Text("Syncing")
                }
                .flintVibrantBackground()
                
            case .activeWorkout:
                Group {
                    Text("Active Workout")
                }
                .flintVibrantBackground()
                
            case .results:
                Group {
                    Text("Results")
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
    }
}

#Preview {
    ContentView()
}
