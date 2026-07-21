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
                    Button(action: {
                        if step > 1 {
                            withAnimation { step = 1 }
                        } else {
                            if viewModel.primaryConnectedPeer != nil {
                                viewModel.activeAlert = .leaveConfirmation
                            } else {
                                withAnimation { viewModel.appState = .home }
                            }
                        }
                    }) {
                        Image(systemName: step > 1 ? "chevron.left" : "xmark")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
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
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 24)
                
                // Scrollable Content
                ZStack(alignment: .top) {
                    Color(white: 0.05)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .ignoresSafeArea(edges: .bottom)
                        
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
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
                                            .background(Color.white.opacity(0.04))
                                            .cornerRadius(18)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(selectedSport == type ? Color.flintRed : Color.white.opacity(0.04), lineWidth: 1.5)
                                            )
                                        }
                                    }
                                }
                                .padding(.top, 24)
                            } else {
                                // STEP 2: Choose Goal
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
                                            .background(Color.white.opacity(0.04))
                                            .cornerRadius(18)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(selectedGoalIndex == index ? Color.flintRed : Color.white.opacity(0.04), lineWidth: 1.5)
                                            )
                                        }
                                    }
                                }
                                .padding(.top, 24)
                            }
                            Spacer().frame(height: 120) // Bottom Padding CTA
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            
            // CTA Button + Fade Gradient
            VStack(spacing: 0) {
                Spacer()
                
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .allowsHitTesting(false)
                
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
                        .padding(.vertical, 16)
                        .background(Color("appRed"))
                        .clipShape(Capsule())
                        .shadow(color: Color("appRed").opacity(0.4), radius: 12, y: 6)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .ignoresSafeArea(.keyboard)
        }
        .navigationBarBackButtonHidden(true)
    }
}
