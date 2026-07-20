import Foundation
import HealthKit
import WatchConnectivity
import Combine
import AVFoundation
import WatchKit

class WatchWorkoutService: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    static let shared = WatchWorkoutService()
    
    @Published var metrics = WorkoutMetrics()
    @Published var workoutResult: String? = nil
    @Published var activeSport: String = "Running"
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    private var timer: Timer?
    private var countdown = 0
    private var currentSessionId: String = ""
    private var isStartingWorkout = false
    
    // Semua tipe data yang dibutuhkan
    private let heartRateType   = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private let calorieType     = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    private let runDistType     = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
    private let cycleDistType   = HKQuantityType.quantityType(forIdentifier: .distanceCycling)!
    private let swimDistType    = HKQuantityType.quantityType(forIdentifier: .distanceSwimming)!
    private let stepCountType   = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let flightsType     = HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!
    
    override init() {
        super.init()
        let hasPresented = UserDefaults.standard.bool(forKey: "hasPresentedWatchPermissions")
        if !hasPresented {
            requestAuthorization { granted in
                if granted {
                    UserDefaults.standard.set(true, forKey: "hasPresentedWatchPermissions")
                }
            }
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType(),
            heartRateType, calorieType, runDistType, cycleDistType, swimDistType, stepCountType, flightsType
        ]
        let typesToRead: Set<HKObjectType> = [
            heartRateType, calorieType, runDistType, cycleDistType, swimDistType, stepCountType, flightsType
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if success {
                print("[Watch] HealthKit auth granted ✓")
            } else {
                print("[Watch] HealthKit auth DENIED: \(error?.localizedDescription ?? "unknown")")
            }
            completion(success)
        }
    }
    
    // MARK: - Workout Lifecycle
    
    /// Entry point SATU-SATUNYA — dipanggil dari WatchAppDelegate.handle(_:)
    func startWorkout(sport: String = "Swimming", sessionId: String = UUID().uuidString) {
        guard !isStartingWorkout else {
            print("[Watch] startWorkout ignored — already in progress")
            return
        }
        if let existing = workoutSession, existing.state == .running {
            print("[Watch] startWorkout ignored — session already running")
            return
        }
        
        isStartingWorkout = true
        self.activeSport = sport
        self.workoutResult = nil
        print("[Watch] startWorkout called — sport: \(sport)")
        
        // Step 1: Minta authorization dulu, BARU start
        requestAuthorization { [weak self] authorized in
            guard let self = self else { return }
            
            if !authorized {
                print("[Watch] Cannot start workout — HealthKit not authorized")
                self.isStartingWorkout = false
                return
            }
            
            // Step 2: Cleanup session lama secara diam-diam
            self.cleanupPreviousSession()
            
            // Step 3: Buat konfigurasi workout
            let configuration = HKWorkoutConfiguration()
            switch sport {
            case "Running":
                configuration.activityType = .running
                configuration.locationType = .outdoor
            case "Cycling":
                configuration.activityType = .cycling
                configuration.locationType = .outdoor
            case "Swimming":
                configuration.activityType = .swimming
                configuration.locationType = .indoor
            default:
                configuration.activityType = .swimming
                configuration.locationType = .indoor
            }
            
            let isDistanceSport = (sport == "Running" || sport == "Cycling" || sport == "Swimming")
            self.currentSessionId = sessionId
            
            do {
                // Step 4: Buat HKWorkoutSession
                let session = try HKWorkoutSession(healthStore: self.healthStore, configuration: configuration)
                let builder = session.associatedWorkoutBuilder()
                
                session.delegate = self
                builder.delegate = self
                
                // DataSource — otomatis pilih sensor HR, distance, calorie sesuai activity
                builder.dataSource = HKLiveWorkoutDataSource(
                    healthStore: self.healthStore,
                    workoutConfiguration: configuration
                )
                
                self.workoutSession = session
                self.workoutBuilder = builder
                
                let startDate = Date()
                
                // Step 5: Start session activity
                session.startActivity(with: startDate)
                
                // Step 6: Begin collection — di sinilah data sensor mulai dikumpulkan
                builder.beginCollection(withStart: startDate) { [weak self] success, error in
                    guard let self = self else { return }
                    self.isStartingWorkout = false
                    
                    DispatchQueue.main.async {
                        if success {
                            print("[Watch] ✓ Collection started — sport: \(sport), sessionId: \(sessionId)")
                            self.metrics = WorkoutMetrics(
                                heartRate: 0.0,
                                distance: 0.0,
                                remainingSeconds: 0,
                                isWorkoutRunning: true,
                                calories: 0.0,
                                isDistanceMetric: isDistanceSport,
                                steps: 0.0,
                                speed: 0.0,
                                elevation: 0.0
                            )
                            self.countdown = 0
                            self.startTimer()
                        } else {
                            let errMsg = error?.localizedDescription ?? "unknown"
                            print("[Watch] ✗ beginCollection failed: \(errMsg)")
                            // Kalau gagal, bersihkan state
                            self.metrics.isWorkoutRunning = false
                            self.workoutSession = nil
                            self.workoutBuilder = nil
                        }
                    }
                }
                
            } catch {
                self.isStartingWorkout = false
                print("[Watch] Failed to create HKWorkoutSession: \(error)")
            }
        }
    }
    
    func updateSessionId(_ sessionId: String) {
        if currentSessionId.isEmpty {
            currentSessionId = sessionId
        }
    }
    
    private var audioPlayer: AVAudioPlayer?
    
    private func playWorkoutResultSound(result: String) {
        let assetName: String
        let hapticType: WKHapticType
        
        switch result {
        case "Victory":
            assetName = "winSound"
            hapticType = .success
        case "Defeat":
            assetName = "defeatSound"
            hapticType = .failure
        case "Solo":
            assetName = "winSound"
            hapticType = .success
        default:
            return
        }
        
        // 1. Play haptic
        WKInterfaceDevice.current().play(hapticType)
        
        // 2. Play sound from data asset catalog
        if let asset = NSDataAsset(name: assetName) {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
                
                audioPlayer = try AVAudioPlayer(data: asset.data)
                audioPlayer?.numberOfLoops = 0
                audioPlayer?.volume = 1.0
                audioPlayer?.play()
                print("[Watch] Successfully playing result sound asset: \(assetName)")
            } catch {
                print("[Watch] Error playing sound asset: \(error.localizedDescription)")
            }
        } else {
            print("[Watch] Sound asset not found in catalog: \(assetName)")
        }
    }
    
    func endWorkout(notifyPhone: Bool = true, result: String? = nil) {
        let sessionId = currentSessionId
        
        timer?.invalidate()
        timer = nil
        isStartingWorkout = false
        
        guard let session = workoutSession else {
            print("[Watch] endWorkout — no active session")
            return
        }
        
        print("[Watch] Ending workout...")
        
        let builder = self.workoutBuilder
        self.workoutSession = nil
        self.workoutBuilder = nil
        
        session.end()
        builder?.endCollection(withEnd: Date()) { _, _ in
            builder?.finishWorkout { _, _ in
                DispatchQueue.main.async {
                    self.metrics.isWorkoutRunning = false
                    self.countdown = 0
                    self.workoutResult = result
                    print("[Watch] Workout ended and saved ✓")
                    if let result = result {
                        self.playWorkoutResultSound(result: result)
                    }
                }
            }
        }
        
        if notifyPhone {
            WatchSessionManager.shared.sendStopSignal(sessionId: sessionId)
        }
    }
    
    private func cleanupPreviousSession() {
        guard let session = workoutSession else { return }
        
        timer?.invalidate()
        timer = nil
        
        let builder = self.workoutBuilder
        self.workoutSession = nil
        self.workoutBuilder = nil
        self.countdown = 0
        
        session.end()
        builder?.endCollection(withEnd: Date()) { _, _ in
            builder?.finishWorkout { _, _ in }
        }
        
        print("[Watch] Previous session cleaned up silently")
    }
    
    // MARK: - Timer & Sync
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.countdown += 1
            DispatchQueue.main.async {
                self.metrics.remainingSeconds = self.countdown
                if self.countdown % 3 == 0 {
                    self.syncMetricsToPhone()
                }
            }
        }
    }
    
    
    // MARK: - HKWorkoutSessionDelegate
    
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {
        print("[Watch] Session state: \(fromState.rawValue) → \(toState.rawValue)")
        if toState == .ended {
            DispatchQueue.main.async {
                self.metrics.isWorkoutRunning = false
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("[Watch] Session error: \(error.localizedDescription)")
        isStartingWorkout = false
        DispatchQueue.main.async {
            self.metrics.isWorkoutRunning = false
        }
    }
    
    // MARK: - HKLiveWorkoutBuilderDelegate
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        var didUpdate = false
        
        for type in collectedTypes {
            guard let qt = type as? HKQuantityType else { continue }
            
            if qt == heartRateType {
                if let stats = workoutBuilder.statistics(for: qt),
                   let q = stats.mostRecentQuantity() {
                    let bpm = q.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    DispatchQueue.main.async { self.metrics.heartRate = bpm }
                    didUpdate = true
                    print("[Watch] HR: \(Int(bpm)) BPM")
                }
            } else if qt == calorieType {
                if let stats = workoutBuilder.statistics(for: qt),
                   let q = stats.sumQuantity() {
                    let kcal = q.doubleValue(for: .kilocalorie())
                    DispatchQueue.main.async { self.metrics.calories = kcal }
                    didUpdate = true
                }
            } else if qt == runDistType {
                if let stats = workoutBuilder.statistics(for: qt),
                   let q = stats.sumQuantity() {
                    let meters = q.doubleValue(for: .meter())
                    DispatchQueue.main.async { self.metrics.distance = Float(meters) }
                    didUpdate = true
                    print("[Watch] Distance (run): \(String(format: "%.1f", meters)) m")
                }
            } else if qt == cycleDistType {
                if let stats = workoutBuilder.statistics(for: qt),
                   let q = stats.sumQuantity() {
                    let meters = q.doubleValue(for: .meter())
                    DispatchQueue.main.async { self.metrics.distance = Float(meters) }
                    didUpdate = true
                }
            } else if qt == swimDistType {
                if let stats = workoutBuilder.statistics(for: qt),
                   let q = stats.sumQuantity() {
                    let meters = q.doubleValue(for: .meter())
                    DispatchQueue.main.async { self.metrics.distance = Float(meters) }
                    didUpdate = true
                    print("[Watch] Distance (swim): \(String(format: "%.1f", meters)) m")
                }
            } else if qt == stepCountType {
                if let stats = workoutBuilder.statistics(for: qt),
                   let q = stats.sumQuantity() {
                    let steps = q.doubleValue(for: .count())
                    DispatchQueue.main.async { self.metrics.steps = steps }
                    didUpdate = true
                    print("[Watch] Steps: \(Int(steps))")
                }
            } else if qt == flightsType {
                if let stats = workoutBuilder.statistics(for: qt),
                   let q = stats.sumQuantity() {
                    let flights = q.doubleValue(for: .count())
                    let elevationMeters = flights * 3.0 // roughly 3m per flight
                    DispatchQueue.main.async { self.metrics.elevation = elevationMeters }
                    didUpdate = true
                    print("[Watch] Elevation: \(Int(elevationMeters)) m")
                }
            }
        }
        
        if didUpdate {
            DispatchQueue.main.async { self.syncMetricsToPhone() }
        }
    }
    
    func syncMetricsToPhone() {
        // Calculate speed dynamically
        let dist = Double(metrics.distance ?? 0.0)
        let elapsed = Double(metrics.remainingSeconds)
        if elapsed > 0 {
            metrics.speed = (dist / 1000.0) / (elapsed / 3600.0)
        } else {
            metrics.speed = 0.0
        }
        
        guard let encoded = try? JSONEncoder().encode(metrics) else { return }
        
        let payload: [String: Any] = [
            "heartRate": metrics.heartRate,
            "distance": dist,
            "calories": metrics.calories,
            "remainingSeconds": metrics.remainingSeconds,
            "isDistanceMetric": metrics.isDistanceMetric,
            "steps": metrics.steps,
            "speed": metrics.speed,
            "elevation": metrics.elevation,
            "metrics": encoded,
            "status": "active",
            "sessionId": currentSessionId
        ]
        WatchSessionManager.shared.sendWorkoutUpdate(data: payload)
    }
}
