import Foundation
import Combine
import NearbyInteraction
import MultipeerConnectivity
import HealthKit

public class iOSWorkoutViewModel: NSObject, ObservableObject {
    @Published var appState: AppState = .home {
        didSet {
            if appState == .searching {
                // Auto-connect after 5 seconds for simulation / testing
                Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    if self.appState == .searching {
                        DispatchQueue.main.async {
                            self.currentRoom = RoomSession(partnerName: "Erling Antetokounmpo", formedAt: Date())
                            self.appState = .room
                        }
                    }
                }
            } else if appState == .syncing {
                // Auto-start workout after 5 seconds for simulation / testing
                Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    if self.appState == .syncing {
                        DispatchQueue.main.async {
                            self.appState = .activeWorkout
                            self.notifyWatchToStartWorkout()
                        }
                    }
                }
            } else if appState == .activeWorkout {
                startLocalWorkoutTimer()
                startRealTimeHealthKitQueries()
            } else if appState == .home || appState == .results {
                stopLocalWorkoutTimer()
                stopRealTimeHealthKitQueries()
            }
        }
    }
    
    @Published var selectedWorkoutType: WorkoutType = .running
    @Published var isChallengeMode: Bool = false
    
    @Published var heartRate: Double = 0.0
    @Published var countdownText: String = "00:00"
    
    @Published public var multipeerManager: MultipeerManager?
    public let niManager = NearbyInteractionManager()
    @Published public var currentRoom: RoomSession?
    
    // Challenge states
    @Published public var selectedChallenge: WorkoutChallenge?
    @Published public var receivedChallenge: WorkoutChallenge?
    
    // Watch Connectivity
    @Published public var watchCalories: Double = 0.0
    private var watchCancellables = Set<AnyCancellable>()
    
    // HealthKit
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var caloriesQuery: HKAnchoredObjectQuery?
    
    @Published var pastWorkouts: [PastWorkout] = [
        PastWorkout(date: Date().addingTimeInterval(-86400 * 2), type: .weightlifting, duration: 2400, avgHeartRate: 135.0),
        PastWorkout(date: Date().addingTimeInterval(-86400 * 5), type: .running, duration: 1800, avgHeartRate: 155.0)
    ]
    
    // Local Fallback Workout Timer
    private var activeWorkoutTimer: Timer?
    private var elapsedSeconds: Int = 0
    private var lastWatchMessageTime: Date?
    
    // Token exchange state
    private var hasSentOwnToken = false
    private var pendingPeerToken: Data?
    private var hasReceivedPeerToken = false
    private var hasSentTokenACK = false
    
    public override init() {
        super.init()
        setupMultipeerManager()
        setupWatchObserving()
        requestHealthKitAuthorization()
    }
    
    private func setupWatchObserving() {
        WatchSessionManager.shared.$workoutState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                
                if let hr = state["heartRate"] as? Double, hr > 0 {
                    self.heartRate = hr
                    self.lastWatchMessageTime = Date()
                }
                
                if let cal = state["calories"] as? Double, cal > 0 {
                    self.watchCalories = cal
                    self.lastWatchMessageTime = Date()
                }
                
                if let secs = state["remainingSeconds"] as? Int, secs > 0 {
                    self.formatCountdownText(seconds: secs)
                    self.lastWatchMessageTime = Date()
                }
                
                if let dist = state["distance"] as? Double {
                    self.niManager.setSimulatedDistance(dist)
                }
                
                if state["status"] as? String == "stopped" {
                    if self.appState == .activeWorkout {
                        self.endWorkoutNatively()
                    }
                }
            }
            .store(in: &watchCancellables)
    }
    
    private func requestHealthKitAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let typesToRead: Set = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, _ in
            if success {
                self?.fetchHealthKitWorkouts()
            }
        }
    }
    
    public func fetchHealthKitWorkouts() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: nil,
            limit: 8,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self = self, let workouts = samples as? [HKWorkout] else { return }
            
            DispatchQueue.main.async {
                let mappedWorkouts = workouts.map { workout -> PastWorkout in
                    let type: WorkoutType
                    switch workout.workoutActivityType {
                    case .running: type = .running
                    case .cycling: type = .cycling
                    default: type = .weightlifting
                    }
                    
                    return PastWorkout(
                        date: workout.startDate,
                        type: type,
                        duration: workout.duration,
                        avgHeartRate: 0.0
                    )
                }
                
                if !mappedWorkouts.isEmpty {
                    self.pastWorkouts = mappedWorkouts
                }
            }
        }
        healthStore.execute(query)
    }
    
    public func setupMultipeerManager() {
        let userName = UserDefaults.standard.string(forKey: "savedUsername") ?? ""
        guard !userName.isEmpty else { return }

        // Reset state
        hasSentOwnToken = false
        pendingPeerToken = nil
        hasReceivedPeerToken = false
        hasSentTokenACK = false

        let manager = MultipeerManager(customDisplayName: userName)
        self.multipeerManager = manager

        manager.onDataReceived = { [weak self] type, payload, peerID in
            guard let self = self else { return }
            switch type {
            case .niDiscoveryToken:
                self.handlePeerTokenReceived(payload)
            case .niTokenACK:
                self.handlePeerACK()
            case .sendChallenge:
                if let challenge = try? JSONDecoder().decode(WorkoutChallenge.self, from: payload) {
                    DispatchQueue.main.async {
                        self.receivedChallenge = challenge
                    }
                }
            case .acceptChallenge:
                DispatchQueue.main.async {
                    self.appState = .activeWorkout
                    self.notifyWatchToStartWorkout()
                }
            case .endWorkout:
                DispatchQueue.main.async {
                    self.endWorkoutNatively()
                }
            default:
                break
            }
        }

        manager.onPeerConnected = { [weak self] _ in
            guard let self = self else { return }
            // Reset state on new connection
            self.hasSentOwnToken = false
            self.pendingPeerToken = nil
            self.hasReceivedPeerToken = false
            self.hasSentTokenACK = false
            
            // Saat peer terkoneksi, ubah appState = .navigating
            DispatchQueue.main.async {
                self.appState = .navigating
            }
            
            // Send our token
            self.sendLocalNIToken()
        }

        niManager.onProximityUpdate = { [weak self] distance in
            guard let self = self else { return }
            
            // Sync live distance to Watch
            self.syncDistanceToWatch(Float(distance))
            
            // Saat jarak < 2.0 meter, ubah appState = .room
            guard distance < 2.0, self.currentRoom == nil else { return }
            let partnerName = self.multipeerManager?.connectedPeer?.displayName ?? "Partner"
            
            DispatchQueue.main.async {
                self.currentRoom = RoomSession(partnerName: partnerName, formedAt: Date())
                self.appState = .room
            }
        }

        manager.onPeerDisconnected = { [weak self] in
            guard let self = self else { return }
            // Reset token exchange state
            self.hasSentOwnToken = false
            self.pendingPeerToken = nil
            self.hasReceivedPeerToken = false
            self.hasSentTokenACK = false
            
            DispatchQueue.main.async {
                self.currentRoom = nil
                self.appState = .home
            }
        }
    }
    
    // MARK: - Token Exchange Handshake

    private func sendLocalNIToken() {
        guard multipeerManager?.connectedPeer != nil else {
            print("[ViewModel] Skipping token send: no connected peer")
            return
        }
        guard !hasSentOwnToken else {
            print("[ViewModel] Already sent own token")
            return
        }
        guard let tokenData = niManager.localTokenData() else { return }

        let envelope = MultipeerMessage(type: .niDiscoveryToken, payload: tokenData)
        if let encoded = try? JSONEncoder().encode(envelope) {
            multipeerManager?.sendData(encoded)
            hasSentOwnToken = true
            print("[ViewModel] Sent local NI token")
        }

        // Try to configure if we already have peer's token
        tryConfigureIfReady()
    }

    private func handlePeerTokenReceived(_ data: Data) {
        print("[ViewModel] Handling peer token")
        pendingPeerToken = data
        hasReceivedPeerToken = true

        // Send ACK immediately so peer knows we received their token
        sendTokenACK()

        // Try to configure
        tryConfigureIfReady()
    }

    private func sendTokenACK() {
        guard multipeerManager?.connectedPeer != nil, !hasSentTokenACK else { return }
        let envelope = MultipeerMessage(type: .niTokenACK, payload: Data())
        if let encoded = try? JSONEncoder().encode(envelope) {
            multipeerManager?.sendData(encoded)
            hasSentTokenACK = true
            print("[ViewModel] Sent token ACK")
        }
    }

    private func handlePeerACK() {
        print("[ViewModel] Peer acknowledged our token")
        // We know peer has our token, they're ready
        tryConfigureIfReady()
    }

    private func tryConfigureIfReady() {
        // Configure NI session only when BOTH conditions are met:
        // 1. We've sent our token
        // 2. We've received peer's token
        guard hasSentOwnToken, hasReceivedPeerToken else {
            print("[ViewModel] Not ready to configure: sent=\(hasSentOwnToken), received=\(hasReceivedPeerToken)")
            return
        }
        guard let peerTokenData = pendingPeerToken else {
            print("[ViewModel] No peer token data")
            return
        }

        print("[ViewModel] Both tokens exchanged, configuring NI session")
        niManager.handleReceivedToken(peerTokenData)
    }

    /// Single entry point untuk cleanup. Dipanggil dari View.
    /// idempotent — aman dipanggil berkali-kali.
    public func fullCleanup() {
        // 1. Reset NI session (ini akan invalidate dan buat session baru)
        niManager.reset()

        // 2. Disconnect Multipeer (callback onPeerDisconnected hanya clear state, tidak reset NI)
        multipeerManager?.disconnect()

        // 3. Clear room state
        currentRoom = nil
        selectedChallenge = nil
        receivedChallenge = nil
        watchCalories = 0.0
        appState = .home

        print("[ViewModel] Full cleanup done")
    }

    // MARK: - Challenge Functions
    
    public func sendChallenge(_ challenge: WorkoutChallenge) {
        if let encoded = try? JSONEncoder().encode(challenge) {
            let message = MultipeerMessage(type: .sendChallenge, payload: encoded)
            if let messageData = try? JSONEncoder().encode(message) {
                multipeerManager?.sendData(messageData)
                self.selectedChallenge = challenge
                self.appState = .syncing // screen: "Waiting for Erling..."
            }
        }
    }
    
    public func acceptChallenge() {
        let message = MultipeerMessage(type: .acceptChallenge, payload: Data())
        if let messageData = try? JSONEncoder().encode(message) {
            multipeerManager?.sendData(messageData)
            self.appState = .activeWorkout
            // Clear received challenge
            self.receivedChallenge = nil
            notifyWatchToStartWorkout()
        }
    }
    
    public func declineChallenge() {
        self.receivedChallenge = nil
        self.appState = .workoutSetup
    }

    // MARK: - Watch Commands
    
    func notifyWatchToStartWorkout() {
        let sport = selectedChallenge?.sport ?? receivedChallenge?.sport ?? selectedWorkoutType
        
        let payload: [String: Any] = [
            "command": "START_WORKOUT",
            "sport": sport.rawValue,
            "status": "active"
        ]
        WatchSessionManager.shared.sendWorkoutUpdate(data: payload)
        
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let configuration = HKWorkoutConfiguration()
        switch sport {
        case .running:
            configuration.activityType = .running
        case .cycling:
            configuration.activityType = .cycling
        case .weightlifting:
            configuration.activityType = .functionalStrengthTraining
        }
        configuration.locationType = .unknown
        
        healthStore.startWatchApp(with: configuration) { success, error in
            if !success {
                print("Failed to start watch app via startWatchApp: \(error?.localizedDescription ?? "unknown error")")
            } else {
                print("Direct startWatchApp request triggered successfully")
            }
        }
    }
    
    func notifyWatchToEndWorkout() {
        WatchSessionManager.shared.sendWorkoutUpdate(data: [
            "status": "stop_request",
            "command": "END_WORKOUT"
        ])
    }
    
    func syncDistanceToWatch(_ distance: Float) {
        WatchSessionManager.shared.sendWorkoutUpdate(data: [
            "distance": Double(distance)
        ])
    }

    // MARK: - Real-Time Local HealthKit Fallback Query (iOS Side)

    private func startRealTimeHealthKitQueries() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)
        
        // 1. Anchored Object Query for Heart Rate
        let hrQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.updateHeartRateSamples(samples)
        }
        
        hrQuery.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.updateHeartRateSamples(samples)
        }
        
        healthStore.execute(hrQuery)
        self.heartRateQuery = hrQuery
        
        // 2. Anchored Object Query for Calories
        let calQuery = HKAnchoredObjectQuery(
            type: calorieType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.updateCalorieSamples(samples)
        }
        
        calQuery.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.updateCalorieSamples(samples)
        }
        
        healthStore.execute(calQuery)
        self.caloriesQuery = calQuery
    }
    
    private func updateHeartRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample], let lastSample = quantitySamples.last else { return }
        let hr = lastSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        DispatchQueue.main.async {
            self.lastWatchMessageTime = Date()
            self.heartRate = hr
        }
    }
    
    private func updateCalorieSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample] else { return }
        let newCalories = quantitySamples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .kilocalorie()) }
        DispatchQueue.main.async {
            self.lastWatchMessageTime = Date()
            self.watchCalories += newCalories
        }
    }
    
    private func stopRealTimeHealthKitQueries() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        if let query = caloriesQuery {
            healthStore.stop(query)
            caloriesQuery = nil
        }
    }

    // MARK: - Local Fallback Timer

    private func startLocalWorkoutTimer() {
        activeWorkoutTimer?.invalidate()
        elapsedSeconds = 0
        heartRate = 0.0
        watchCalories = 0.0
        lastWatchMessageTime = nil
        formatCountdownText(seconds: 0)
        
        activeWorkoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.elapsedSeconds += 1
                
                let isWatchActive = self.isWatchConnectedAndSendingData()
                if !isWatchActive {
                    self.formatCountdownText(seconds: self.elapsedSeconds)
                }
            }
        }
    }
    
    private func stopLocalWorkoutTimer() {
        activeWorkoutTimer?.invalidate()
        activeWorkoutTimer = nil
    }
    
    private func isWatchConnectedAndSendingData() -> Bool {
        guard let lastTime = lastWatchMessageTime else { return false }
        return Date().timeIntervalSince(lastTime) < 3.0
    }

    private func formatCountdownText(seconds: Int) {
        let mins = seconds / 60
        let secs = seconds % 60
        self.countdownText = String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Compatibility helpers for old view references
    func invite(peer: MCPeerID) {
        multipeerManager?.invite(peer)
    }
    
    func acceptInvite() {
        multipeerManager?.acceptInvitation()
    }
    
    func declineInvite() {
        multipeerManager?.declineInvitation()
    }
    
    func startWorkout() {
        appState = .activeWorkout
        notifyWatchToStartWorkout()
    }
    
    public func endWorkout() {
        sendEndWorkoutCommandToPartner()
        endWorkoutNatively()
    }
    
    private func sendEndWorkoutCommandToPartner() {
        let message = MultipeerMessage(type: .endWorkout, payload: Data())
        if let messageData = try? JSONEncoder().encode(message) {
            multipeerManager?.sendData(messageData)
        }
    }
    
    private func endWorkoutNatively() {
        notifyWatchToEndWorkout()
        stopLocalWorkoutTimer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.fetchHealthKitWorkouts()
        }
        appState = .results
    }
    
    func rematch() {
        appState = .workoutSetup
    }
    
    func forgetWorkout(_ workout: PastWorkout) {
        pastWorkouts.removeAll { $0.id == workout.id }
    }
}
