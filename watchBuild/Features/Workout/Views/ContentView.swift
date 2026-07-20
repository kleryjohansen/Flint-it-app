import SwiftUI
import HealthKit

// MARK: - Root Content View

struct ContentView: View {
    @StateObject private var viewModel = WatchWorkoutViewModel()

    var body: some View {
        Group {
            if let result = viewModel.workoutResult {
                WatchResultsView(result: result, viewModel: viewModel)
            } else if viewModel.isWorkoutRunning {
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

// MARK: - Active Workout View

struct WatchWorkoutView: View {
    @ObservedObject var viewModel: WatchWorkoutViewModel

    var body: some View {
        ZStack {
            VStack(spacing: 6) {
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
                
                // Distance Row (Running figure icon + distance text)
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color("appPrimary"))
                    Text(viewModel.distanceString)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(Color(white: 0.14))
                .clipShape(Capsule())
                
                Spacer(minLength: 0)
                
                // Pace and BPM Row (side by side)
                HStack(spacing: 6) {
                    // Avg Pace
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color("appPrimary"))
                        Text(viewModel.avgPaceString)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(Color(white: 0.14))
                    .clipShape(Capsule())
                    
                    // BPM
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color("appPrimary"))
                        Text(viewModel.bpmString)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(Color(white: 0.14))
                    .clipShape(Capsule())
                }
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

    // MARK: Top bar — workout icon
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
        }
    }
}

// MARK: - Watch Results View

struct WatchResultsView: View {
    let result: String
    @ObservedObject var viewModel: WatchWorkoutViewModel
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer(minLength: 5)
                
                // ZStack containing the large background rays and the trophy button centered EXACTLY inside it
                ZStack {
                    if result == "Victory" || result == "Solo" {
                        Image("winBackground")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 220, height: 220)
                    } else {
                        Image("loseBackground")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 220, height: 220)
                    }
                    
                    // Central button - perfectly in the center of the background rays
                    Button(action: {
                        withAnimation {
                            viewModel.dismissResults()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color("appPrimary"))
                                .frame(width: 80, height: 80)
                                .shadow(color: Color("appPrimary").opacity(0.4), radius: 6)
                            
                            if result == "Victory" || result == "Solo" {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "hands.clap.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 80, height: 80)
                }
                .frame(width: 220, height: 115)
                
                Spacer(minLength: 4)
                
                // Titles and detail messages stacked tightly below the button
                VStack(spacing: 2) {
                    if result == "Victory" || result == "Solo" {
                        Text("Congratulations!")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("You've just won")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Try again buddy!")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Nice try on")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                    
                    Text("1km sprint • Run")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color("appPrimary"))
                        .multilineTextAlignment(.center)
                }
                
                Spacer(minLength: 6)
            }
            .padding(.horizontal, 8)
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
