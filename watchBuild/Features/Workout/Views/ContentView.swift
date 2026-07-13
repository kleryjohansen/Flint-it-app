import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WatchWorkoutViewModel()
    
    var body: some View {
        VStack(spacing: 8) {
            Text(viewModel.timerString)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.yellow)
            
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text(viewModel.bpmString)
                    .font(.title2)
                    .bold()
            }
            
            Spacer()
            
            Button(action: {
                viewModel.startTracking()
            }) {
                Text("Start Tracking")
                    .bold()
            }
            .tint(.green)
        }
        .padding()
    }
}
