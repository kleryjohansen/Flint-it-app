import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WatchWorkoutViewModel()
    @State private var pulseHeart = false
    
    var body: some View {
        VStack(spacing: 8) {
            if viewModel.isWorkoutRunning {
                // ACTIVE WORKOUT UI
                VStack(spacing: 12) {
                    Text(viewModel.timerString)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                        .monospacedDigit()
                    
                    HStack(spacing: 12) {
                        // Heart rate
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .scaleEffect(pulseHeart ? 1.2 : 1.0)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                        pulseHeart = true
                                    }
                                }
                            Text(viewModel.bpmString)
                                .font(.body.bold())
                                .foregroundColor(.white)
                        }
                        
                        // Active metric selection (distance vs calories)
                        if viewModel.isDistanceMetric {
                            HStack(spacing: 4) {
                                Image(systemName: "figure.run")
                                    .foregroundColor(.blue)
                                Text(viewModel.distanceString)
                                    .font(.body.bold())
                                    .foregroundColor(.white)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                Text(viewModel.caloriesString)
                                    .font(.body.bold())
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.stopTracking()
                    }) {
                        Text("End Workout")
                            .font(.body.bold())
                            .foregroundColor(.white)
                    }
                    .tint(.red)
                    .controlSize(.small)
                }
            } else {
                // INACTIVE WORKOUT UI
                VStack(spacing: 16) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 4) {
                        Text("Flint Workout")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Waiting for iPhone...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        viewModel.startTracking()
                    }) {
                        Text("Start Local")
                            .bold()
                    }
                    .tint(.green)
                    .controlSize(.small)
                }
            }
        }
        .padding(8)
        .onAppear {
            WatchWorkoutService.shared.requestAuthorization()
        }
    }
}

#Preview {
    ContentView()
}
