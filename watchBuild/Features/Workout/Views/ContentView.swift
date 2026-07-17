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
                        .font(.title).bold()
                        .foregroundColor(Color("appYellow"))
                        .monospacedDigit()

                    HStack(spacing: 8) {
                        // Heart rate
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(Color("appRed"))
                                .scaleEffect(pulseHeart ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulseHeart)
                                .onAppear { pulseHeart = true }
                            Text(viewModel.bpmString)
                                .font(.body.bold())
                                .foregroundColor(.primary)
                        }

                        // Distance or calories
                        if viewModel.isDistanceMetric {
                            HStack(spacing: 4) {
                                Image(systemName: "figure.run").foregroundColor(Color("appBlue"))
                                Text(viewModel.distanceString)
                                    .font(.body.bold()).foregroundColor(.primary)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill").foregroundColor(Color("appOrange"))
                                Text(viewModel.caloriesString)
                                    .font(.body.bold()).foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color("appGlassWhite"))
                    .cornerRadius(10)

                    // Average Pace Display
                    Text("Avg Pace: \(viewModel.avgPaceString)")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)

                    Spacer()
                }

            } else {
                // WAITING FOR iOS
                VStack(spacing: 12) {
                    Image(systemName: "iphone")
                        .font(.title2)
                        .foregroundColor(Color("appOrange"))

                    Text("Nearfit")
                        .font(.headline.bold())
                        .foregroundColor(.primary)

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
