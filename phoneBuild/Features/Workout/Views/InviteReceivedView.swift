import SwiftUI
import MultipeerConnectivity

struct InviteReceivedView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Adaptive vibrant background
            Color.clear
                .flintVibrantBackground()

            VStack(spacing: 28) {
                // Header Graphic
                ZStack {
//                    Circle()
//                        .fill(Color.flintRed.opacity(0.12))
//                        .frame(width: 96, height: 96)

                    Image(systemName: "figure.run")
                        .font(.largeTitle)
                        .foregroundColor(Color.white)
                        .padding(.horizontal, 3)
                }
                .padding(12)
                .glassEffect(.clear.tint(.flintRed))
                .padding(.top, 16)

                VStack(spacing: 24) {
                    Text("\(viewModel.multipeerManager?.pendingInvitingPeer?.displayName ?? "Someone") invite you to a challenge!")
                        .font(.title3).bold()
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location Sharing Required")
                            .font(.footnote).bold()
                            .foregroundColor(.primary)

                        Text("Accepting will share your real-time distance and direction with this device during the session. Your location is never stored or uploaded.")
                            .font(.caption2)
                            .foregroundColor(Color("appSecondaryLabel"))
                            .lineSpacing(4)
                    }
                    .padding(12)
                    .flintGlassCard()
                }

                // Action Buttons
                HStack(spacing: 8) {
                    Button(action: {
                        viewModel.declineInvite()
                        dismiss()
                    }) {
                        Text("Decline")
                            .font(.callout).bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.regular)
                    .buttonBorderShape(.automatic)
//                    .tint(.accentColor)

                    Button(action: {
                        viewModel.acceptInvite()
                        dismiss()
                    }) {
                        Text("Accept")
                            .font(.callout).bold()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.regular)
                    .buttonBorderShape(.automatic)
                    .tint(.flintRed)
                }
                .padding(.bottom, 16)
            }
            .padding(24)
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    InviteReceivedView()
        .environmentObject(iOSWorkoutViewModel())
}
