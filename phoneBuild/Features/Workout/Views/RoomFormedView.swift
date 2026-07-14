import SwiftUI

struct RoomFormedView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)

            Text("Workout Room Ready!")
                .font(.largeTitle.bold())
                .foregroundColor(.white)

            if let room = viewModel.currentRoom {
                VStack(spacing: 8) {
                    Text("Partner")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(room.partnerName)
                        .font(.title2)
                        .foregroundColor(.orange)
                }
            }

            Button("Start Workout") {
                viewModel.startWorkout()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)

            Button("Cancel / Exit") {
                viewModel.fullCleanup()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.white)
            .controlSize(.large)
            .padding(.top, 10)

            Spacer()
            Spacer()
        }
        .padding()
        .background(Color.flintBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    RoomFormedView()
        .environmentObject(iOSWorkoutViewModel())
}
