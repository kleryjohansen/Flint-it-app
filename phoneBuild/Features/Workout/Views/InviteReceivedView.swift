import SwiftUI
import MultipeerConnectivity

struct InviteReceivedView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Dark base background
            Color(red: 0.05, green: 0.04, blue: 0.04)
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                // Header Graphic
                ZStack {
                    Circle()
                        .fill(Color.flintRed.opacity(0.12))
                        .frame(width: 96, height: 96)
                    
                    Image(systemName: "figure.run")
                        .font(.system(size: 44))
                        .foregroundColor(Color.flintRed)
                }
                .padding(.top, 16)

                VStack(spacing: 12) {
                    Text("\(viewModel.multipeerManager?.pendingInvitingPeer?.displayName ?? "Someone") wants to work out with you!")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location Sharing Required")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Accepting will share your real-time distance and direction with this device during the session. Your location is never stored or uploaded.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(18)
                }

                // Action Buttons
                HStack(spacing: 16) {
                    Button(action: {
                        viewModel.declineInvite()
                        dismiss()
                    }) {
                        Text("Decline")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Button(action: {
                        viewModel.acceptInvite()
                        dismiss()
                    }) {
                        Text("Accept")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.flintRed)
                            .clipShape(Capsule())
                            .shadow(color: Color.flintRed.opacity(0.3), radius: 10, y: 5)
                    }
                }
                .padding(.bottom, 16)
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
    }
}

#Preview {
    InviteReceivedView()
        .environmentObject(iOSWorkoutViewModel())
}
