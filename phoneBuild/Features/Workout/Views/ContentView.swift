import SwiftUI
import MultipeerConnectivity

struct ContentView: View {
    @StateObject private var viewModel = iOSWorkoutViewModel()
    
    var body: some View {
        Group {
            switch viewModel.appState {
            case .discovery, .profile:
                DiscoveryView(viewModel: viewModel)
            case .workoutSelection:
                WorkoutSelectionView(viewModel: viewModel)
            case .connected:
                ConnectedView(viewModel: viewModel)
            case .activeWorkout:
                ActiveWorkoutDashboard(viewModel: viewModel)
            case .results:
                ResultsView(viewModel: viewModel)
            }
        }
        .alert(item: $viewModel.connectivityService.incomingInvite) { invite in
            Alert(
                title: Text("Workout Invite"),
                message: Text("\(invite.peerID.displayName) wants to workout together."),
                primaryButton: .default(Text("Accept")) {
                    viewModel.acceptInvite()
                },
                secondaryButton: .cancel(Text("Decline")) {
                    viewModel.declineInvite()
                }
            )
        }
    }
}
