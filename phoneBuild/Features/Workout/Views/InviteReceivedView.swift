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
                    Circle()
                        .fill(Color.flintRed.opacity(0.12))
                        .frame(width: 96, height: 96)

                    Image(systemName: "figure.run")
                        .font(.largeTitle)
                        .foregroundColor(Color.flintRed)
                }
                .padding(.top, 16)

                VStack(spacing: 12) {
                    Text("\(viewModel.multipeerManager?.pendingInvitingPeer?.displayName ?? "Someone") wants to work out with you!")
                        .font(.title3).bold()
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location Sharing Required")
                            .font(.footnote).bold()
                            .foregroundColor(.primary)

                        Text("Accepting will share your real-time distance and direction with this device during the session. Your location is never stored or uploaded.")
                            .font(.caption)
                            .foregroundColor(Color("appSecondaryLabel"))
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .flintGlassCard()
                }

                // Action Buttons
                HStack(spacing: 16) {
                    Button(action: {
                        viewModel.multipeerManager?.declineInvitation()
                        dismiss()
                    }) {
                        Text("Decline")
                            .font(.callout).bold()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PillButtonStyle(color: Color("appGlassBorder")))
                    .colorScheme(.light) // Force light style untuk kontras di kedua mode

                    Button(action: {
                        viewModel.multipeerManager?.acceptInvitation()
                        dismiss()
                    }) {
                        Text("Accept")
                            .font(.callout).bold()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PillButtonStyle())
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
