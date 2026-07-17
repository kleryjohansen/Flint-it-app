import Foundation
import Combine

class WatchWorkoutViewModel: ObservableObject {
    @Published var bpmString: String = "-- BPM"
    @Published var timerString: String = "00:00"
    @Published var isWorkoutRunning: Bool = false
    @Published var caloriesString: String = "0.0 kcal"
    @Published var isDistanceMetric: Bool = false
    @Published var distanceString: String = "0.0 m"
    @Published var avgPaceString: String = "--:--"
    
    private let workoutService = WatchWorkoutService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        workoutService.$metrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                guard let self = self else { return }
                self.bpmString = metrics.heartRate > 0 ? "\(Int(metrics.heartRate)) BPM" : "-- BPM"
                self.formatTimer(seconds: metrics.remainingSeconds)
                self.isWorkoutRunning = metrics.isWorkoutRunning
                self.caloriesString = String(format: "%.1f kcal", metrics.calories)
                self.isDistanceMetric = metrics.isDistanceMetric
                if let dist = metrics.distance {
                    self.distanceString = String(format: "%.1f m", dist)
                    if dist > 5 {
                        let distanceKm = Double(dist) / 1000.0
                        let paceSecondsPerKm = Double(metrics.remainingSeconds) / distanceKm
                        let minutes = Int(paceSecondsPerKm) / 60
                        let seconds = Int(paceSecondsPerKm) % 60
                        if minutes < 100 {
                            self.avgPaceString = String(format: "%d:%02d /km", minutes, seconds)
                        } else {
                            self.avgPaceString = "--:--"
                        }
                    } else {
                        self.avgPaceString = "--:--"
                    }
                } else {
                    self.distanceString = "0.0 m"
                    self.avgPaceString = "--:--"
                }
            }
            .store(in: &cancellables)
    }
    
    func startTracking() {
        workoutService.startWorkout()
    }
    
    func stopTracking() {
        workoutService.endWorkout()
    }
    
    private func formatTimer(seconds: Int) {
        let mins = seconds / 60
        let secs = seconds % 60
        self.timerString = String(format: "%02d:%02d", mins, secs)
    }
}
