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
    @State private var showExitConfirmation = false
    
    // Goals configuration
    private let runningCyclingGoals = [
        (name: "15M Sprint", subtitle: "Fastest to finish 15m wins", value: 0.015, metric: "distance"),
        (name: "5KM Distance", subtitle: "Fastest to finish 5km wins", value: 5.0, metric: "distance"),
        (name: "15 Min Endurance", subtitle: "Longest distance in 15 mins wins", value: 15.0, metric: "distance")
    ]
    
    private let swimmingGoals = [
        (name: "15M Swim Sprint", subtitle: "Fastest to swim 15m wins", value: 0.015, metric: "distance"),
        (name: "100 Calories Burned", subtitle: "Fastest to burn 100 kcal wins", value: 100.0, metric: "calories"),
        (name: "200 Calories Burned", subtitle: "Fastest to burn 200 kcal wins", value: 200.0, metric: "calories")
    ]
    
    public init() {}

    public var body: some View {
            ZStack(alignment: .top) {
                // Force strict black background behind everything ignoring system theme
                Color.black.ignoresSafeArea()
                
                // Top background image
                Image("bgLobby")
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .mask(LinearGradient(gradient: Gradient(colors: [.black, .black.opacity(0)]), startPoint: .top, endPoint: .bottom))
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Nav
                    HStack {
                        var glassStyle: Glass = .regular

                        Button(action: {
                            if step > 1 {
                                withAnimation { step = 1 }
                            } else {
                                if viewModel.multipeerManager?.connectedPeer != nil {
                                    viewModel.activeAlert = .leaveConfirmation
                                } else {
                                    withAnimation { viewModel.appState = .home }
                                }
                            }
                        }
                        ) {
                            // Use chevron if going back a step, otherwise use xmark to close
                            Image(systemName: step > 1 ? "chevron.left" : "xmark")
                                .font(.title3.bold())
                                .foregroundStyle(.primary)
                                .frame(width: 32, height: 44)
                        }
                        .buttonStyle(.glass(glassStyle))
                        .controlSize(.regular)
                        .buttonBorderShape(.automatic)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 40)
                    
                    // Title Area
                    VStack(alignment: .leading, spacing: 8) {
                        Text(step == 1 ? "Choose a sport" : "Choose your challenge")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        Text(step == 1 ? "Select the activity you want to compete in" : "Pick the exact goal for your rivals")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 60)
                    .padding(.bottom, 24)

                    // Scrollable Content Area with Dark Card Background behind it
                    ZStack(alignment: .top) {
                        // Dark backing card hugging the entire lists section
                        Color(white: 0.05)
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                            .ignoresSafeArea(edges: .bottom)
                            
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                
                                if step == 1 {
                                    // STEP 1: Choose a Sport
                                    VStack(spacing: 12) {
                                        ForEach(WorkoutType.allCases) { type in
                                            Button(action: {
                                                withAnimation { selectedSport = type }
                                            }) {
                                                HStack(spacing: 16) {
                                                    ZStack {
                                                        Circle()
                                                            .fill(selectedSport == type ? Color.flintRed : Color.white.opacity(0.1))
                                                            .frame(width: 40, height: 40)
                                                        
                                                        Image(systemName: type.iconName)
                                                            .font(.system(size: 16, weight: .bold))
                                                            .foregroundColor(.white)
                                                    }
                                                    
                                                    Text(type.rawValue)
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(.white)
                                                    
                                                    Spacer()
                                                }
                                                .padding(.vertical, 14)
                                                .padding(.horizontal, 16)
                                                .background(
                                                    ZStack {
                                                            if selectedSport == type {
                                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                                    .fill(
                                                                        LinearGradient(
                                                                            colors: [Color.flintRed.opacity(0.3), Color.appTertiary.opacity(0.1)],
                                                                            startPoint: .leading,
                                                                            endPoint: .trailing
                                                                        )
                                                                    )
                                                            }
                                                        }
                                                )
                                                .cornerRadius(18)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 18)
                                                        .stroke(selectedSport == type ? Color.flintRed : Color.white.opacity(0.04), lineWidth: 1.5)
                                                    
                                                )
                                            }
                                        }
                                    }
                                } else {
                                    // STEP 2: Choose your Challenge Goal
                                    VStack(spacing: 12) {
                                        let activeGoals = selectedSport == .swimming ? swimmingGoals : runningCyclingGoals
                                        ForEach(0..<activeGoals.count, id: \.self) { index in
                                            let goal = activeGoals[index]
                                            Button(action: {
                                                withAnimation { selectedGoalIndex = index }
                                            }) {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(goal.name)
                                                            .font(.system(size: 16, weight: .bold))
                                                            .foregroundColor(.white)
                                                        Text(goal.subtitle)
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.white.opacity(0.5))
                                                    }
                                                    Spacer()
                                                }
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 16)
                                                .background(
                                                    ZStack {
                                                            if selectedGoalIndex == index {
                                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                                    .fill(
                                                                        LinearGradient(
                                                                            colors: [Color.flintRed.opacity(0.3), Color.appTertiary.opacity(0.1)],
                                                                            startPoint: .leading,
                                                                            endPoint: .trailing
                                                                        )
                                                                    )
                                                            }
                                                        }
                                                )
                                                .cornerRadius(18)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 18)
                                                        .stroke(selectedGoalIndex == index ? Color.flintRed : Color.white.opacity(0.04), lineWidth: 1.5)
                                                )
                                            }
                                        }
                                    }
                                }
                                
                                Spacer().frame(height: 120) // Bottom padding for fixed CTA button
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                        }
                    }
                } // End main Vertical
                
                // Floating CTA Button at the absolute bottom
                VStack {
                    Spacer()
                    
                    Button(action: {
                        if step == 1 {
                            withAnimation { step = 2 }
                        } else {
                            let activeGoals = selectedSport == .swimming ? swimmingGoals : runningCyclingGoals
                            let goal = activeGoals[selectedGoalIndex]
                            let challenge = WorkoutChallenge(
                                sport: selectedSport,
                                goalValue: goal.value,
                                challengeName: goal.name,
                                metricType: goal.metric
                            )
                            viewModel.sendChallenge(challenge)
                        }
                    }) {
                        Text(step == 1 ? "Continue" : "Send Challenge")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
//                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .buttonBorderShape(.automatic)
                    .tint(.flintRed)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 70)
                }
                .ignoresSafeArea(.keyboard)
            }
            .preferredColorScheme(.dark)
            .navigationBarBackButtonHidden(true)
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
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Circle().fill(Color.white.opacity(0.1)))
                        }
                        Spacer()
                        
                        Text("Challenging...")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
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
                                .stroke(Color.white.opacity(0.06), lineWidth: 6)
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
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                }
            }
            .flintVibrantBackground()
            .navigationBarBackButtonHidden(true)
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
                Color(red: 0.05, green: 0.04, blue: 0.04)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header Graphic
                    ZStack {
                        Circle()
                            .fill(Color.flintRed.opacity(0.12))
                            .frame(width: 96, height: 96)
                        
                        Image(systemName: challenge.sport.iconName)
                            .font(.system(size: 40))
                            .foregroundColor(Color.flintRed)
                    }
                    .padding(.top, 16)

                    // Info Cards
                    VStack(spacing: 12) {
                        Text("\(viewModel.multipeerManager?.connectedPeer?.displayName ?? "Partner") challenged you!")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: 6) {
                            Text("Sport: \(challenge.sport.rawValue)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text(challenge.challengeName)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
    }
#Preview("Setup") {
    let mockGuestVM = iOSWorkoutViewModel()
    // Force it to falsely act like a guest to reveal the guest elements
    mockGuestVM.isHost = false
    return WorkoutSetupView()
        .environmentObject(mockGuestVM)
}
