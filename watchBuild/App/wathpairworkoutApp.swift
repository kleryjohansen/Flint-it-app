import SwiftUI
import WatchKit
import HealthKit

class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        print("[WatchAppDelegate] Received workout configuration from iOS")
        let sportName: String
        switch workoutConfiguration.activityType {
        case .running:
            sportName = "Running"
        case .cycling:
            sportName = "Cycling"
        case .swimming:
            sportName = "Swimming"
        default:
            sportName = "Swimming"
        }
        
        DispatchQueue.main.async {
            WatchWorkoutService.shared.startWorkout(sport: sportName)
        }
    }
}

@main
struct wathpairworkout_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
