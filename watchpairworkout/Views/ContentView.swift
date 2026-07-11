import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = iOSWorkoutViewModel()
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Proximity Workout")
                .font(.largeTitle)
                .bold()
            
            VStack {
                Text(viewModel.connectivityService.isPeerConnected ? "Connected" : "Searching for Peer...")
                    .foregroundColor(viewModel.connectivityService.isPeerConnected ? .green : .red)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
                
                if let distance = viewModel.distanceToPeer {
                    Text(String(format: "Distance: %.2f m", distance))
                        .font(.headline)
                        .padding(.top, 10)
                }
            }
            
            VStack(spacing: 20) {
                Text(viewModel.countdownText)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("\(Int(viewModel.heartRate)) BPM")
                        .font(.title)
                }
            }
            .padding()
            
            Spacer()
            
            Button(action: {
                viewModel.connectivityService.notifyWatchToStartWorkout()
            }) {
                Text("START WORKOUT ON WATCH")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
}
