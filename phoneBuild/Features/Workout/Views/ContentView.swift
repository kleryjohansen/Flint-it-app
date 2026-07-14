import SwiftUI
import MultipeerConnectivity

struct ContentView: View {
    @StateObject private var viewModel = iOSWorkoutViewModel()
    
    var body: some View {
        switch viewModel.appState {
        case .home:
            Group {
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("Welcome to Flint")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    
                    Text("Your workout partner finder is ready.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Button(action: {
                        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    }) {
                        Text("Log Out / Reset Onboarding")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(15)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }
            .flintVibrantBackground()
            
        case .searching:
            Group {
                Text("Searching")
            }
            .flintVibrantBackground()
            
        case .foundPartner:
            Group {
                Text("Found Partner")
            }
            .flintVibrantBackground()
            
        case .navigating:
            Group {
                Text("Navigating")
            }
            .flintVibrantBackground()
            
        case .workoutSetup:
            Group {
                Text("Workout Setup")
            }
            .flintVibrantBackground()
            
        case .syncing:
            Group {
                Text("Syncing")
            }
            .flintVibrantBackground()
            
        case .activeWorkout:
            Group {
                Text("Active Workout")
            }
            .flintVibrantBackground()
            
        case .results:
            Group {
                Text("Results")
            }
            .flintVibrantBackground()
        }
    }
}
