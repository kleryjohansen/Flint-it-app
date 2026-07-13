import Foundation
import HealthKit
import WatchConnectivity
import Combine

class WatchWorkoutService: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, WCSessionDelegate {
    
    @Published var metrics = WorkoutMetrics()
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    private var timer: Timer?
    private var countdown = 0
    
    var wcSession: WCSession?
    
    override init() {
        super.init()
        setupWatchConnectivity()
        requestAuthorization()
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
        }
    }
    
    private func requestAuthorization() {
        let typesToShare: Set = [HKQuantityType.workoutType()]
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if !success {
                print("HealthKit authorization failed")
            }
        }
    }
    
    func startWorkout() {
        guard workoutSession == nil else { return }
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining
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
            }
            startTimer()
            
        } catch {
            print("Failed to start workout: \(error)")
        }
    }
    
    func endWorkout() {
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
                self.syncMetricsToPhone()
            }
        }
    }
    
    func syncMetricsToPhone() {
        guard let session = wcSession, session.isReachable else { return }
        
        if let data = try? JSONEncoder().encode(metrics) {
            session.sendMessage(["metrics": data], replyHandler: nil, errorHandler: { error in
                print("Error sending metrics: \(error.localizedDescription)")
            })
        }
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let command = message["command"] as? String, command == "START_WORKOUT" {
            DispatchQueue.main.async {
                if !self.metrics.isWorkoutRunning {
                    self.startWorkout()
                }
            }
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
            }
        }
    }
}
