import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var viewModel = WatchWorkoutViewModel()
    @State private var pulseHeart = false
    @State private var authStatus = "Checking..."
    
    var body: some View {
        VStack(spacing: 8) {
            if viewModel.isWorkoutRunning {
                // ACTIVE WORKOUT UI
                VStack(spacing: 10) {
                    Text(viewModel.timerString)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.yellow)
                        .monospacedDigit()
                    
                    HStack(spacing: 8) {
                        // Heart rate
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .scaleEffect(pulseHeart ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulseHeart)
                                .onAppear { pulseHeart = true }
                            Text(viewModel.bpmString)
                                .font(.body.bold())
                                .foregroundColor(.white)
                        }
                        
                        // Distance or calories
                        if viewModel.isDistanceMetric {
                            HStack(spacing: 4) {
                                Image(systemName: "figure.run").foregroundColor(.blue)
                                Text(viewModel.distanceString)
                                    .font(.body.bold()).foregroundColor(.white)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill").foregroundColor(.orange)
                                Text(viewModel.caloriesString)
                                    .font(.body.bold()).foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                    
                    Spacer()
                    
                    Button(action: { viewModel.stopTracking() }) {
                        Text("End Workout")
                            .font(.body.bold())
                            .foregroundColor(.white)
                    }
                    .tint(.red)
                    .controlSize(.small)
                }
                
            } else {
                // WAITING FOR iOS
                VStack(spacing: 12) {
                    Image(systemName: "iphone")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    
                    Text("Flint")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    
                    Text("Start workout\nfrom iPhone")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(8)
        .onAppear {
            // Request izin HealthKit saat Watch app dibuka supaya
            // saat iOS trigger startWatchApp, izin sudah siap
            WatchWorkoutService.shared.requestAuthorization { granted in
                DispatchQueue.main.async {
                    authStatus = granted ? "Ready" : "Health access needed"
                    if !granted {
                        print("[Watch] HealthKit permission not yet granted — will show dialog")
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
