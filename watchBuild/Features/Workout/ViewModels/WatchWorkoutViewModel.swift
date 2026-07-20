import Foundation
import Combine
import WatchKit

class WatchWorkoutViewModel: ObservableObject {
    @Published var bpmString: String    = "-- /Bpm"
    @Published var timerString: String  = "00:00:00"
    @Published var isWorkoutRunning: Bool = false
    @Published var caloriesString: String = "0.0 kcal"
    @Published var isDistanceMetric: Bool = false
    @Published var distanceString: String = "0.0 m"
    @Published var avgPaceString: String  = "--:-- /km"
    @Published var stepsString: String    = "0 steps"
    @Published var speedString: String    = "0.0 km/h"
    @Published var workoutResult: String? = nil
    
    // Countdown state local to watch
    @Published var countdownSeconds: Int = -1
    private var countdownTimer: Timer?
    private var wasRunning: Bool = false

    private let workoutService = WatchWorkoutService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Observe result
        workoutService.$workoutResult
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.workoutResult = result
            }
            .store(in: &cancellables)

        workoutService.$metrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                guard let self = self else { return }

                // Check for start trigger
                let running = metrics.isWorkoutRunning
                if running && !self.wasRunning {
                    self.startLocalCountdown()
                }
                self.wasRunning = running
                self.isWorkoutRunning = running
                self.isDistanceMetric = metrics.isDistanceMetric

                // Heart rate
                self.bpmString = metrics.heartRate > 0
                    ? "\(Int(metrics.heartRate)) /Bpm"
                    : "-- /Bpm"

                // Elapsed timer (HH:MM:SS) - held at 0 during countdown
                if self.countdownSeconds >= 0 {
                    self.timerString = "00:00:00"
                } else {
                    self.formatTimer(seconds: metrics.remainingSeconds)
                }

                // Calories
                self.caloriesString = String(format: "%.1f kcal", metrics.calories)

                // Steps
                self.stepsString = metrics.steps > 0
                    ? "\(Int(metrics.steps)) steps"
                    : "0 steps"

                // Speed (m/s → km/h)
                let kmh = metrics.speed * 3.6
                self.speedString = kmh > 0
                    ? String(format: "%.1f km/h", kmh)
                    : "0.0 km/h"

                // Distance + avg pace
                if let dist = metrics.distance {
                    let meters = Double(dist)
                    if meters >= 1000 {
                        self.distanceString = String(format: "%.2f km", meters / 1000)
                    } else {
                        self.distanceString = String(format: "%.0f m", meters)
                    }
                    // Pace: only meaningful once we have >10 m and some elapsed time
                    let elapsed = metrics.remainingSeconds
                    if meters > 10, elapsed > 0 {
                        let paceSecPerKm = Double(elapsed) / (meters / 1000.0)
                        let pMins = Int(paceSecPerKm) / 60
                        let pSecs = Int(paceSecPerKm) % 60
                        self.avgPaceString = pMins < 100
                            ? String(format: "%d:%02d /km", pMins, pSecs)
                            : "--:-- /km"
                    } else {
                        self.avgPaceString = "--:-- /km"
                    }
                } else {
                    self.distanceString = "0.0 m"
                    self.avgPaceString  = "--:-- /km"
                }
            }
            .store(in: &cancellables)
    }

    func startTracking() { workoutService.startWorkout() }
    func stopTracking()  {
        // Reset countdown state
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownSeconds = -1
        workoutService.endWorkout()
    }

    private func startLocalCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        
        countdownSeconds = 3
        triggerCountdownHaptic(isFinal: false)
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if self.countdownSeconds > 1 {
                    self.countdownSeconds -= 1
                    self.triggerCountdownHaptic(isFinal: false)
                } else if self.countdownSeconds == 1 {
                    self.countdownSeconds = 0 // GO!
                    self.triggerCountdownHaptic(isFinal: true)
                } else {
                    self.countdownSeconds = -1
                    self.countdownTimer?.invalidate()
                    self.countdownTimer = nil
                }
            }
        }
    }

    private func triggerCountdownHaptic(isFinal: Bool) {
        #if os(watchOS)
        let type: WKHapticType = isFinal ? .success : .click
        WKInterfaceDevice.current().play(type)
        #endif
    }

    private func formatTimer(seconds: Int) {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        timerString = String(format: "%02d:%02d:%02d", h, m, s)
    }

    func dismissResults() {
        workoutService.workoutResult = nil
    }
}
