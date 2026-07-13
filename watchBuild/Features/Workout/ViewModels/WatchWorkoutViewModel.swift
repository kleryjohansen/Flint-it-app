import Foundation
import Combine

class WatchWorkoutViewModel: ObservableObject {
    @Published var bpmString: String = "-- BPM"
    @Published var timerString: String = "00:00"
    
    private let workoutService = WatchWorkoutService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        workoutService.$metrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.bpmString = metrics.heartRate > 0 ? "\(Int(metrics.heartRate)) BPM" : "-- BPM"
                self?.formatTimer(seconds: metrics.remainingSeconds)
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
