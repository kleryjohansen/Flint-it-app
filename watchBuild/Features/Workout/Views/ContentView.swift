import SwiftUI
import HealthKit

// MARK: - Root Content View

struct ContentView: View {
    @StateObject private var viewModel = WatchWorkoutViewModel()

    var body: some View {
        Group {
            if viewModel.isWorkoutRunning {
                WatchWorkoutView(viewModel: viewModel)
            } else {
                WatchIdleView()
            }
        }
        .onAppear {
            // Reset any previous ghost workout state from previous closed launch
            WatchWorkoutService.shared.endWorkout(notifyPhone: false)
            
            let hasPresented = UserDefaults.standard.bool(forKey: "hasPresentedWatchPermissions")
            if !hasPresented {
                WatchWorkoutService.shared.requestAuthorization { granted in
                    if granted {
                        UserDefaults.standard.set(true, forKey: "hasPresentedWatchPermissions")
                    } else {
                        print("[Watch] HealthKit permission not yet granted — will show dialog")
                    }
                }
            }
        }
    }
}

// MARK: - Active Workout View (Time, Distance & Pace ONLY)

struct WatchWorkoutView: View {
    @ObservedObject var viewModel: WatchWorkoutViewModel

    var body: some View {
        ZStack {
            VStack(spacing: 4) {
                // Top Bar
                topBar
                
                Spacer(minLength: 0)
                
                // Time / Duration Label (HH:MM:SS)
                Text(viewModel.timerString)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer(minLength: 0)
                
                // Distance Pill
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color("appPrimary"))
                    Text(viewModel.distanceString)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Color(white: 0.14))
                .clipShape(Capsule())
                
                Spacer(minLength: 0)
                
                // Avg Pace Pill
                HStack(spacing: 6) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color("appPrimary"))
                    Text(viewModel.avgPaceString)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Color(white: 0.14))
                .clipShape(Capsule())
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)
            .padding(.bottom, 4)

            // Countdown Overlay
            if viewModel.countdownSeconds >= 0 {
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 4) {
                        Text(viewModel.countdownSeconds == 0 ? "GO!" : "\(viewModel.countdownSeconds)")
                            .font(.system(size: viewModel.countdownSeconds == 0 ? 44 : 52, weight: .black, design: .rounded))
                            .foregroundColor(Color("appPrimary"))
                            .transition(.scale.combined(with: .opacity))
                            .id(viewModel.countdownSeconds)
                            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: viewModel.countdownSeconds)

                        Text("RIVALRY START")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: Top bar — workout icon + live clock
    private var topBar: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(Color("appPrimary").opacity(0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: "figure.run")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color("appPrimary"))
            }

            Spacer()

            Text(Date(), style: .time)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

// MARK: - Idle / Waiting View

struct WatchIdleView: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color("appPrimary").opacity(0.12))
                    .frame(width: 54, height: 54)
                    .scaleEffect(pulse ? 1.15 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: pulse
                    )
                Image(systemName: "iphone")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color("appPrimary"))
            }
            .onAppear { pulse = true }

            Text("Nearfit")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Start workout\nfrom iPhone")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
