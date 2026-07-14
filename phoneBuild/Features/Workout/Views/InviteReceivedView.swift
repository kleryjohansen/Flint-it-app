import SwiftUI
import MultipeerConnectivity

struct InviteReceivedView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "figure.run")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("\(viewModel.multipeerManager?.pendingInvitingPeer?.displayName ?? "Someone") wants to work out with you!")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .foregroundColor(.white)

            VStack(spacing: 12) {
                Text("Location Sharing")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Accepting will share your approximate location (distance and direction) with this device in real-time during the workout session. Your location is not stored anywhere.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)

            HStack(spacing: 20) {
                Button {
                    viewModel.multipeerManager?.declineInvitation()
                    dismiss()
                } label: {
                    Text("Decline")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    viewModel.multipeerManager?.acceptInvitation()
                    dismiss()
                } label: {
                    Text("Accept")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)
            }
        }
        .padding(32)
        .preferredColorScheme(.dark)
        .background(Color.flintBackground.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}

#Preview {
    InviteReceivedView()
        .environmentObject(iOSWorkoutViewModel())
}
