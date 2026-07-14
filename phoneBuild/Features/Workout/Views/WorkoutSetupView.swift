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
            // Main Content
            VStack(spacing: 20) {
                // Header Bar
                HStack {
                    Button(action: {
                        if step > 1 {
                            withAnimation { step = 1 }
                        } else {
                            viewModel.appState = .room
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Create Challenge")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Empty space for balance
                    Spacer().frame(width: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                // Form Card
                VStack(spacing: 24) {
                    if step == 1 {
                        // STEP 1: Choose a Sport
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Choose a sport")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            
                            VStack(spacing: 12) {
                                ForEach(WorkoutType.allCases) { type in
                                    Button(action: {
                                        selectedSport = type
                                    }) {
                                        HStack(spacing: 16) {
                                            ZStack {
                                                Circle()
                                                    .fill(selectedSport == type ? Color.flintRed : Color.white.opacity(0.1))
                                                    .frame(width: 44, height: 44)
                                                
                                                Image(systemName: type.iconName)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Text(type.rawValue)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            
                                            Spacer()
                                            
                                            if selectedSport == type {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(Color.flintRed)
                                                    .font(.title3)
                                            }
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(selectedSport == type ? Color.white.opacity(0.1) : Color.clear)
                                        .cornerRadius(15)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(selectedSport == type ? Color.flintRed.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            
                            Button(action: {
                                withAnimation { step = 2 }
                            }) {
                                Text("Continue")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FlintPrimaryButtonStyle(isWhite: false))
                            .padding(.top, 10)
                        }
                    } else {
                        // STEP 2: Choose your Challenge
                        VStack(alignment: .leading, spacing: 16) {
                            Button(action: {
                                withAnimation { step = 1 }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Choose your challenge")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white.opacity(0.7))
                            }
                            
                            VStack(spacing: 12) {
                                let activeGoals = selectedSport == .weightlifting ? weightliftingGoals : runningCyclingGoals
                                ForEach(0..<activeGoals.count, id: \.self) { index in
                                    let goal = activeGoals[index]
                                    Button(action: {
                                        selectedGoalIndex = index
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(goal.name)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                Text(goal.subtitle)
                                                    .font(.caption)
                                                    .foregroundColor(.white.opacity(0.5))
                                            }
                                            Spacer()
                                            
                                            if selectedGoalIndex == index {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(Color.flintRed)
                                                    .font(.title3)
                                            }
                                        }
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 16)
                                        .background(selectedGoalIndex == index ? Color.white.opacity(0.1) : Color.clear)
                                        .cornerRadius(15)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(selectedGoalIndex == index ? Color.flintRed.opacity(0.5) : Color.white.opacity(0.05), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            
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
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FlintPrimaryButtonStyle(isWhite: false))
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
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Challenge Waiting View (Screen 3)
public struct ChallengeWaitingView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @State private var spinAnimation = false
    
    public init() {}

    public var body: some View {
        ZStack {
            VStack {
                // Header
                HStack {
                    Button(action: {
                        viewModel.appState = .workoutSetup
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Challenge sent")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Spacer().frame(width: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                // Radar / Loading Ring
                ZStack {
                    // Pulsing Glow
                    Circle()
                        .fill(Color.flintRed.opacity(0.1))
                        .frame(width: 240, height: 240)
                    
                    // Rotating outer ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [Color.flintRed, Color.flintRed.opacity(0.1)]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(spinAnimation ? 360 : 0))
                        .onAppear {
                            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                spinAnimation = true
                            }
                        }
                }
                
                Spacer()
                
                // Text Description
                Text("Waiting for \(viewModel.multipeerManager?.connectedPeer?.displayName ?? "Partner")...")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .padding(.bottom, 60)
            }
        }
        .flintVibrantBackground()
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Challenge Received Modal / Overlay
public struct ChallengeReceivedView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    let challenge: WorkoutChallenge

    public var body: some View {
        VStack(spacing: 32) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: challenge.sport.iconName)
                    .font(.system(size: 44))
                    .foregroundColor(Color.flintRed)
            }

            VStack(spacing: 8) {
                Text("\(viewModel.multipeerManager?.connectedPeer?.displayName ?? "Partner") challenged you!")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Sport: \(challenge.sport.rawValue)")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(challenge.challengeName)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 4)
            }

            HStack(spacing: 20) {
                Button {
                    viewModel.declineChallenge()
                } label: {
                    Text("Decline")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    viewModel.acceptChallenge()
                } label: {
                    Text("Accept & Start")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.flintRed)
                .controlSize(.large)
            }
        }
        .padding(32)
        .preferredColorScheme(.dark)
        .background(Color.flintBackground.ignoresSafeArea())
        .presentationDetents([.medium])
    }
}
