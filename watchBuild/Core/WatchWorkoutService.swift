import Foundation
import HealthKit
import WatchConnectivity
import Combine

class WatchWorkoutService: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    static let shared = WatchWorkoutService()
    
    @Published var metrics = WorkoutMetrics()
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    private var timer: Timer?
    private var countdown = 0
    
    override init() {
        super.init()
        requestAuthorization()
    }
    
    func requestAuthorization() {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        
        let typesToShare: Set = [
            HKQuantityType.workoutType(),
            hrType,
            calorieType,
            distanceType
        ]
        let typesToRead: Set = [
            hrType,
            calorieType,
            distanceType
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if !success {
                print("HealthKit authorization failed: \(error?.localizedDescription ?? "unknown error")")
            } else {
                print("HealthKit authorization succeeded")
            }
        }
    }
    
    func startWorkout(sport: String = "Weightlifting") {
        guard workoutSession == nil else { return }
        
        let configuration = HKWorkoutConfiguration()
        switch sport {
        case "Running":
            configuration.activityType = .running
        case "Cycling":
            configuration.activityType = .cycling
        default:
            configuration.activityType = .functionalStrengthTraining
        }
        configuration.locationType = .unknown
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            workoutBuilder?.beginCollection(withStart: startDate, completion: { success, error in
                // Handle errors
            })
            
            DispatchQueue.main.async {
                self.metrics.isWorkoutRunning = true
                self.metrics.isDistanceMetric = (sport == "Running" || sport == "Cycling")
                self.metrics.distance = 0.0
            }
            startTimer()
            
        } catch {
            print("Failed to start workout: \(error)")
        }
    }
    
    func endWorkout() {
        guard workoutSession != nil else { return }
        
        // Notify phone that watch is stopped
        WatchSessionManager.shared.sendWorkoutUpdate(data: ["status": "stopped"])
        
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date(), completion: { success, error in
            self.workoutBuilder?.finishWorkout(completion: { workout, error in
                DispatchQueue.main.async {
                    self.metrics.isWorkoutRunning = false
                    self.workoutSession = nil
                    self.workoutBuilder = nil
                }
            })
        })
        
        timer?.invalidate()
        timer = nil
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.countdown += 1
            DispatchQueue.main.async {
                self.metrics.remainingSeconds = self.countdown
                
                // Keep watch UI ticking, and send data to phone every 5 seconds
                if self.countdown % 5 == 0 {
                    self.syncMetricsToPhone()
                }
            }
        }
    }
    
    func syncMetricsToPhone() {
        if let data = try? JSONEncoder().encode(metrics) {
            let payload: [String: Any] = [
                "heartRate": self.metrics.heartRate,
                "distance": Double(self.metrics.distance ?? 0.0),
                "metrics": data,
                "status": "active"
            ]
            WatchSessionManager.shared.sendWorkoutUpdate(data: payload)
        }
    }
    
    // MARK: - HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        if toState == .ended {
            DispatchQueue.main.async {
                self.metrics.isWorkoutRunning = false
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
    
    // MARK: - HKLiveWorkoutBuilderDelegate
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            if quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) {
                if let statistics = workoutBuilder.statistics(for: quantityType),
                   let heartRate = statistics.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) {
                    DispatchQueue.main.async {
                        self.metrics.heartRate = heartRate
                        self.syncMetricsToPhone()
                    }
                }
            } else if quantityType == HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                if let statistics = workoutBuilder.statistics(for: quantityType),
                   let activeEnergy = statistics.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) {
                    DispatchQueue.main.async {
                        self.metrics.calories = activeEnergy
                        self.syncMetricsToPhone()
                    }
                }
            } else if quantityType == HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
                if let statistics = workoutBuilder.statistics(for: quantityType),
                   let distanceValue = statistics.sumQuantity()?.doubleValue(for: HKUnit.meter()) {
                    DispatchQueue.main.async {
                        self.metrics.distance = Float(distanceValue)
                        self.syncMetricsToPhone()
                    }
                }
            }
        }
    }
}
