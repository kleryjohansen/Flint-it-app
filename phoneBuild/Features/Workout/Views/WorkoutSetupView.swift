import SwiftUI
import MultipeerConnectivity

public struct IdentifiableChallenge: Identifiable {
    public var id: String { challenge.challengeName }
    public let challenge: WorkoutChallenge
}

public struct WorkoutSetupView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @State private var step: Int = 1
    @State private var selectedSport: WorkoutType = .running
    @State private var selectedGoalIndex: Int = 0

    // Goals configuration
    private let runningCyclingGoals = [
        (name: "1KM Sprint", subtitle: "Fastest to finish 1km wins", value: 1.0, metric: "distance"),
        (name: "5KM Distance", subtitle: "Fastest to finish 5km wins", value: 5.0, metric: "distance"),
        (name: "15 Min Endurance", subtitle: "Longest distance in 15 mins wins", value: 15.0, metric: "distance")
    ]

    private let weightliftingGoals = [
        (name: "100 Calories Burned", subtitle: "Fastest to burn 100 kcal wins", value: 100.0, metric: "calories"),
        (name: "200 Calories Burned", subtitle: "Fastest to burn 200 kcal wins", value: 200.0, metric: "calories"),
        (name: "300 Calories Burned", subtitle: "Fastest to burn 300 kcal wins", value: 300.0, metric: "calories")
    ]

    public init() {}

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header Bar (Screen 6/7 style)
                HStack {
                    Button(action: {
                        if step > 1 {
                            withAnimation { step = 1 }
                        } else {
                            withAnimation { viewModel.appState = .room }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .foregroundColor(.white) // Intentional: di atas fixed brand background
                            .padding(10)
                            .background(Circle().fill(.ultraThinMaterial))
                    }

                    Spacer()

                    Text("Create Challenge")
                        .font(.callout.bold())
                        .foregroundColor(.white) // Intentional: di atas fixed brand background

                    Spacer()
                    Spacer().frame(width: 44) // Balance back button
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Form Content Card (matches Screen 6 & 7 glassmorphic card)
                VStack(spacing: 24) {
                    if step == 1 {
                        // STEP 1: Choose a Sport
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Choose a sport")
                                .font(.callout.bold())
                                .foregroundColor(Color("appSecondaryLabel"))
                                .tracking(1)
                                .padding(.horizontal, 4)

                            VStack(spacing: 12) {
                                ForEach(WorkoutType.allCases) { type in
                                    Button(action: {
                                        withAnimation { selectedSport = type }
                                    }) {
                                        HStack(spacing: 16) {
                                            ZStack {
                                                Circle()
                                                    .fill(selectedSport == type ? Color.flintRed : Color("appGlassWhite"))
                                                    .frame(width: 40, height: 40)

                                                Image(systemName: type.iconName)
                                                    .font(.callout.bold())
                                                    .foregroundColor(.white) // Intentional: di atas circle brand/glass background
                                            }

                                            Text(type.rawValue)
                                                .font(.callout.bold())
                                                .foregroundColor(.white) // Intentional: di atas fixed brand background

                                            Spacer()
                                        }
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 16)
                                        .background(Color("appGlassWhite").opacity(0.5))
                                        .cornerRadius(18)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(selectedSport == type ? Color.flintRed : Color("appGlassWhite").opacity(0.5), lineWidth: 1.5)
                                        )
                                    }
                                }
                            }

                            // Bottom capsule button inside the layout
                            Button(action: {
                                withAnimation { step = 2 }
                            }) {
                                Text("Continue")
                                    .font(.callout.bold())
                                    .foregroundColor(.white) // Intentional: di atas tombol brand Color.flintRed
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.flintRed)
                                    .clipShape(Capsule())
                                    .shadow(color: Color.flintRed.opacity(0.35), radius: 12, y: 6)
                            }
                            .padding(.top, 10)
                        }
                    } else {
                        // STEP 2: Choose your Challenge
                        VStack(alignment: .leading, spacing: 20) {
                            Button(action: {
                                withAnimation { step = 1 }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.left")
                                    Text("Choose your challenge")
                                }
                                .font(.callout.bold())
                                .foregroundColor(Color("appSecondaryLabel"))
                            }
                            .padding(.horizontal, 4)

                            VStack(spacing: 12) {
                                let activeGoals = selectedSport == .weightlifting ? weightliftingGoals : runningCyclingGoals
                                ForEach(0..<activeGoals.count, id: \.self) { index in
                                    let goal = activeGoals[index]
                                    Button(action: {
                                        withAnimation { selectedGoalIndex = index }
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(goal.name)
                                                    .font(.callout.bold())
                                                    .foregroundColor(.white) // Intentional: di atas fixed brand background
                                                Text(goal.subtitle)
                                                    .font(.caption)
                                                    .foregroundColor(Color("appSecondaryLabel"))
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 16)
                                        .padding(.horizontal, 16)
                                        .background(Color("appGlassWhite").opacity(0.5))
                                        .cornerRadius(18)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(selectedGoalIndex == index ? Color.flintRed : Color("appGlassWhite").opacity(0.5), lineWidth: 1.5)
                                        )
                                    }
                                }
                            }

                            // Send Challenge button
                            Button(action: {
                                let activeGoals = selectedSport == .weightlifting ? weightliftingGoals : runningCyclingGoals
                                let goal = activeGoals[selectedGoalIndex]
                                let challenge = WorkoutChallenge(
                                    sport: selectedSport,
                                    goalValue: goal.value,
                                    challengeName: goal.name,
                                    metricType: goal.metric
                                )
                                viewModel.sendChallenge(challenge)
                            }) {
                                Text("Send Challenge")
                                    .font(.callout.bold())
                                    .foregroundColor(.white) // Intentional: di atas tombol brand Color.flintRed
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.flintRed)
                                    .clipShape(Capsule())
                                    .shadow(color: Color.flintRed.opacity(0.35), radius: 12, y: 6)
                            }
                            .padding(.top, 10)
                        }
                    }
                }
                .padding(24)
                .flintGlassCard()
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .flintVibrantBackground()
    }
}

// MARK: - Challenge Waiting View (Screen 8 style)

public struct ChallengeWaitingView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @State private var spinAnimation = false
    @State private var showWaitingSkip = false

    public init() {}

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header (Screen 8 waiting state)
                HStack {
                    Button(action: {
                        withAnimation {
                            viewModel.appState = .workoutSetup
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .foregroundColor(.white) // Intentional: di atas fixed brand background
                            .padding(10)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    Spacer()

                    Text("Challenging...")
                        .font(.callout.bold())
                        .foregroundColor(.white) // Intentional: di atas fixed brand background

                    Spacer()
                    Spacer().frame(width: 44) // Balance back button
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Spinner & Progress visual (Screen 8 style)
                VStack(spacing: 40) {
                    ZStack {
                        // Ambient red halo glow
                        Circle()
                            .fill(Color.flintRed.opacity(0.12))
                            .frame(width: 220, height: 220)
                            .blur(radius: 20)

                        // Background track ring
                        Circle()
                            .stroke(Color("appGlassWhite"), lineWidth: 6)
                            .frame(width: 140, height: 140)

                        // Rotating gradient indicator ring
                        Circle()
                            .trim(from: 0.0, to: 0.35)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.flintRed, Color.flintRed.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 140, height: 140)
                            .rotationEffect(.degrees(spinAnimation ? 360 : 0))
                            .onAppear {
                                withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                                    spinAnimation = true
                                }
                            }
                    }

                    // Spinner Status Description Text
                    VStack(spacing: 8) {
                        Text("Waiting for \(viewModel.multipeerManager?.connectedPeer?.displayName ?? "Partner")...")
                            .font(.title3)
                            .foregroundColor(.white) // Intentional: di atas fixed brand background

                        Text("Waiting to bring workout...")
                            .font(.subheadline)
                            .foregroundColor(Color("appSecondaryLabel"))

                        if showWaitingSkip {
                            Button(action: {
                                withAnimation {
                                    viewModel.skipWaitingAndStartWorkout()
                                }
                            }) {
                                Text("Start Workout Solo")
                                    .font(.callout.bold())
                                    .foregroundColor(.white) // Intentional: di atas tombol brand Color("appPrimary")
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 28)
                                    .background(Color("appPrimary"))
                                    .clipShape(Capsule())
                                    .shadow(color: Color("appPrimary").opacity(0.35), radius: 10, y: 5)
                            }
                            .padding(.top, 24)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }

                Spacer()
            }
        }
        .flintVibrantBackground()
        .onAppear {
            // Trigger skip button helper after 5 seconds of waiting
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation {
                    showWaitingSkip = true
                }
            }
        }
    }
}

// MARK: - Challenge Received Modal / Overlay

public struct ChallengeReceivedView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    let challenge: WorkoutChallenge

    public var body: some View {
        ZStack {
            // Dark base background
            Color("appBrandBackground")
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Header Graphic
                ZStack {
                    Circle()
                        .fill(Color.flintRed.opacity(0.12))
                        .frame(width: 96, height: 96)

                    Image(systemName: challenge.sport.iconName)
                        .font(.largeTitle)
                        .foregroundColor(Color.flintRed)
                }
                .padding(.top, 16)

                // Info Cards
                VStack(spacing: 12) {
                    Text("\(viewModel.multipeerManager?.connectedPeer?.displayName ?? "Partner") challenged you!")
                        .font(.title3.bold())
                        .foregroundColor(.white) // Intentional: di atas fixed Color("appBrandBackground")
                        .multilineTextAlignment(.center)

                    VStack(spacing: 6) {
                        Text("Sport: \(challenge.sport.rawValue)")
                            .font(.callout.bold())
                            .foregroundColor(Color("appSecondaryLabel"))

                        Text(challenge.challengeName)
                            .font(.caption)
                            .foregroundColor(Color("appSecondaryLabel"))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color("appGlassWhite").opacity(0.5))
                    .cornerRadius(16)
                }

                // Action Buttons
                HStack(spacing: 16) {
                    Button(action: {
                        viewModel.declineChallenge()
                    }) {
                        Text("Decline")
                            .font(.callout.bold())
                            .foregroundColor(Color("appSecondaryLabel"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("appGlassWhite"))
                            .clipShape(Capsule())
                    }

                    Button(action: {
                        viewModel.acceptChallenge()
                    }) {
                        Text("Accept & Start")
                            .font(.callout.bold())
                            .foregroundColor(.white) // Intentional: di atas tombol brand Color.flintRed
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
    WorkoutSetupView()
        .environmentObject(iOSWorkoutViewModel())
}
