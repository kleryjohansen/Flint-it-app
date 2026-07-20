import SwiftUI
import HealthKit

// MARK: - Root Content View

struct ContentView: View {
    @StateObject private var viewModel = WatchWorkoutViewModel()

    var body: some View {
        Group {
            if viewModel.isWorkoutRunning {
                WatchWorkoutView(viewModel: viewModel)
            } else if viewModel.workoutResult != nil {
                WatchWorkoutResultView(viewModel: viewModel)
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

// MARK: - Active Workout View

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
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer(minLength: 0)
                
                // Distance Pill
                HStack(spacing: 6) {
                    Image(systemName: viewModel.activeSport == "Cycling" ? "figure.outdoor.cycle" : (viewModel.activeSport == "Swimming" ? "figure.pool.swim" : "figure.run"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color("appPrimary"))
                    Text(viewModel.distanceString)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(Color(white: 0.12))
                .clipShape(Capsule())
                
                Spacer(minLength: 0)
                
                // Bottom metrics: Pace & Heart rate side-by-side
                HStack(spacing: 6) {
                    // Left capsule: Pace
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.system(size: 10))
                            .foregroundColor(Color("appPrimary"))
                        Text(viewModel.avgPaceString)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(Color(white: 0.12))
                    .clipShape(Capsule())
                    
                    // Right capsule: Heart rate
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color("appPrimary"))
                        Text(viewModel.bpmString.replacingOccurrences(of: " BPM", with: "/Bpm"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(Color(white: 0.12))
                    .clipShape(Capsule())
                }
                
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
                Image(systemName: viewModel.activeSport == "Cycling" ? "figure.outdoor.cycle" : (viewModel.activeSport == "Swimming" ? "figure.pool.swim" : "figure.run"))
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

// MARK: - Workout Result View

struct WatchWorkoutResultView: View {
    @ObservedObject var viewModel: WatchWorkoutViewModel

    var body: some View {
        ZStack {
            Image(viewModel.workoutResult == "Victory" || viewModel.workoutResult == "Solo" ? "winBackground" : "loseBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 8) {
                    // Central Trophy / Clapping badge with rays
                    ZStack {
                        Image(viewModel.workoutResult == "Victory" || viewModel.workoutResult == "Solo" ? "winBackground" : "loseBackground")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .opacity(0.85)
                        
                        ZStack {
                            Circle()
                                .fill(Color("appPrimary"))
                                .frame(width: 50, height: 50)
                                .shadow(color: Color("appPrimary").opacity(0.4), radius: 6)
                            
                            if viewModel.workoutResult == "Victory" || viewModel.workoutResult == "Solo" {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "hands.clap.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(height: 100)
                    
                    VStack(spacing: 2) {
                        if viewModel.workoutResult == "Victory" || viewModel.workoutResult == "Solo" {
                            Text("Congratulations!")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("You've just won")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                        } else {
                            Text("Try again buddy!")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Nice try on")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Text("1km sprint • \(viewModel.activeSport)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color("appPrimary"))
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        withAnimation {
                            viewModel.workoutResult = nil
                            WatchWorkoutService.shared.workoutResult = nil
                        }
                    }) {
                        Text("Done")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(height: 32)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .padding(.top, 4)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
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
