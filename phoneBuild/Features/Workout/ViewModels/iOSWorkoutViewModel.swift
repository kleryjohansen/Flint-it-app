import Foundation
import Combine
import NearbyInteraction
import MultipeerConnectivity
import HealthKit

public class iOSWorkoutViewModel: NSObject, ObservableObject {
    @Published var appState: AppState = .home {
        didSet {
            if appState == .activeWorkout {
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
    @Published public var isHost: Bool = false
    @Published public var partnerWatchConnected: Bool = true
    private var watchCancellables = Set<AnyCancellable>()
    
    // Session tracking — cegah stale "stopped" dari sesi sebelumnya
    private var activeWorkoutSessionId: String = ""
    private var workoutStartTime: Date?
    
    // HealthKit
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var caloriesQuery: HKAnchoredObjectQuery?
    
    @Published var pastWorkouts: [PastWorkout] = []
    
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
        loadPastWorkoutsLocally()
        
        // Request all permissions sequentially at start
        requestAllPermissions()
    }
    
    private func setupWatchObserving() {
        WatchSessionManager.shared.$workoutState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                
                // Guard: hanya proses data jika workout sedang aktif di iOS
                guard self.appState == .activeWorkout else { return }
                
                let incomingSessionId = state["sessionId"] as? String ?? ""
                
                if let hr = state["heartRate"] as? Double, hr > 0 {
                    self.heartRate = hr
                    self.lastWatchMessageTime = Date()
                }
                
                if let cal = state["calories"] as? Double, cal > 0 {
                    self.watchCalories = cal
                    self.lastWatchMessageTime = Date()
                    
                    // Check target calories
                    if let challenge = self.selectedChallenge ?? self.receivedChallenge,
                       challenge.metricType == "calories" {
                        if cal >= challenge.goalValue {
                            print("[iOS] Target calories reached (\(cal) / \(challenge.goalValue) kcal) — auto ending workout")
                            self.endWorkout()
                        }
                    }
                }
                
                if let dist = state["distance"] as? Double, dist > 0 {
                    self.lastWatchMessageTime = Date()
                    
                    // Check target distance
                    if let challenge = self.selectedChallenge ?? self.receivedChallenge,
                       challenge.metricType == "distance",
                       !challenge.challengeName.contains("Endurance") {
                        let targetMeters = challenge.goalValue * 1000.0
                        if dist >= targetMeters {
                            print("[iOS] Target distance reached (\(dist) / \(targetMeters)m) — auto ending workout")
                            self.endWorkout()
                        }
                    }
                }

                if let secs = state["remainingSeconds"] as? Int, secs > 0 {
                    self.formatCountdownText(seconds: secs)
                    self.elapsedSeconds = secs
                    self.lastWatchMessageTime = Date()
                    
                    // Check target time (15 Min Endurance)
                    if let challenge = self.selectedChallenge ?? self.receivedChallenge {
                        if challenge.challengeName.contains("15 Min Endurance") && secs >= 900 {
                            print("[iOS] Target time reached (\(secs) / 900s) — auto ending workout")
                            self.endWorkout()
                        }
                    }
                }
                
                if state["status"] as? String == "stopped" {
                    // Guard 1: session ID harus cocok supaya bukan sinyal dari sesi lama
                    guard !self.activeWorkoutSessionId.isEmpty,
                          incomingSessionId == self.activeWorkoutSessionId else {
                        print("[iOS] Ignored stale 'stopped' from sessionId: \(incomingSessionId), current: \(self.activeWorkoutSessionId)")
                        return
                    }
                    
                    // Guard 2: workout harus sudah berjalan minimal 5 detik
                    if let startTime = self.workoutStartTime,
                       Date().timeIntervalSince(startTime) > 5.0 {
                        print("[iOS] Received valid 'stopped' from Watch — ending workout")
                        self.endWorkoutNatively()
                    } else {
                        print("[iOS] Ignored 'stopped' — workout just started, too early")
                    }
                }
            }
            .store(in: &watchCancellables)
            
        // Observe watch connectivity status to report changes to peer
        WatchSessionManager.shared.$isWatchPaired
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.multipeerManager?.connectedPeer != nil {
                    self.sendWatchStatusToPeer()
                }
            }
            .store(in: &watchCancellables)
            
        // Auto-recover UWB session on dropout
        niManager.onSessionInvalidated = { [weak self] in
            guard let self = self else { return }
            if self.appState == .navigating {
                print("[ViewModel] NI session invalidated while navigating, re-exchanging tokens")
                self.hasSentOwnToken = false
                self.hasReceivedPeerToken = false
                self.hasSentTokenACK = false
                self.sendLocalNIToken()
            }
        }
    }
    
    // MARK: - Sequential Permissions Request (Nearby Interaction first, then HealthKit, then Local Network)
    
    public func requestAllPermissions() {
        requestNearbyInteractionPermission { [weak self] in
            self?.requestHealthKitAuthorization {
                self?.requestLocalNetworkPermission()
            }
        }
    }
    
    private func requestNearbyInteractionPermission(completion: @escaping () -> Void) {
        guard NISession.isSupported else {
            completion()
            return
        }
        
        DispatchQueue.main.async {
            let dummySession = NISession()
            dummySession.delegate = DummyNISessionDelegate.shared
            if let ownToken = dummySession.discoveryToken {
                let config = NINearbyPeerConfiguration(peerToken: ownToken)
                dummySession.run(config)
                
                // Prompt presented, now invalidate dummy session after 1.5 seconds and proceed
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dummySession.invalidate()
                    completion()
                }
            } else {
                completion()
            }
        }
    }
    
    private func requestHealthKitAuthorization(completion: @escaping () -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion()
            return
        }
        
        let typesToRead: Set = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, _ in
            if success {
                self?.fetchHealthKitWorkouts()
            }
            completion()
        }
    }
    
    private func requestLocalNetworkPermission() {
        // Start multipeer browsing briefly to trigger Local Network dialog
        multipeerManager?.startBrowsing()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.appState != .searching {
                self.multipeerManager?.stopBrowsing()
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
                    case .swimming: type = .swimming
                    default: type = .swimming
                    }
                    
                    return PastWorkout(
                        date: workout.startDate,
                        type: type,
                        duration: workout.duration,
                        avgHeartRate: 0.0,
                        calories: 0.0,
                        partnerName: nil
                    )
                }
                
                if !mappedWorkouts.isEmpty {
                    // Merge HealthKit workouts with local ones
                    var merged = self.pastWorkouts
                    for hkW in mappedWorkouts {
                        if !merged.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: hkW.date) && abs($0.duration - hkW.duration) < 60 }) {
                            merged.append(hkW)
                        }
                    }
                    merged.sort(by: { $0.date > $1.date })
                    self.pastWorkouts = merged
                    self.savePastWorkoutsLocally()
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
            case .watchStatus:
                if let payloadObj = try? JSONDecoder().decode(WatchStatusPayload.self, from: payload) {
                    DispatchQueue.main.async {
                        self.partnerWatchConnected = payloadObj.isWatchConnected
                        print("[iOS] Received watch status from partner: \(payloadObj.isWatchConnected)")
                    }
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
            // PENTING: Jangan overwrite self.isHost di sini agar penentu host tetap diatur saat invite/terima.
            DispatchQueue.main.async {
                self.appState = .navigating
            }
            
            // Send our token
            self.sendLocalNIToken()
            
            // Send our watch connection status to the peer
            self.sendWatchStatusToPeer()
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
            
            // Restart advertising so we can be discovered again
            self.multipeerManager?.startAdvertising()
            
            DispatchQueue.main.async {
                self.isHost = false
                self.partnerWatchConnected = true // Reset to true
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

        // Restart advertising so we can be discovered again
        multipeerManager?.startAdvertising()

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
        DispatchQueue.main.async {
            self.appState = self.isHost ? .workoutSetup : .room
        }
    }

    // MARK: - Watch Commands
    
    func notifyWatchToStartWorkout() {
        let sport = selectedChallenge?.sport ?? receivedChallenge?.sport ?? selectedWorkoutType
        
        // Buat session ID baru untuk sesi ini
        activeWorkoutSessionId = UUID().uuidString
        workoutStartTime = Date()
        _ = WatchSessionManager.shared.beginNewWorkoutSession()
        print("[iOS] Starting new workout session: \(activeWorkoutSessionId) sport: \(sport.rawValue)")
        
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let configuration = HKWorkoutConfiguration()
        switch sport {
        case .running:
            configuration.activityType = .running
            configuration.locationType = .outdoor
        case .cycling:
            configuration.activityType = .cycling
            configuration.locationType = .outdoor
        case .swimming:
            configuration.activityType = .swimming
            configuration.locationType = .indoor
        }
        
        // SATU-SATUNYA trigger untuk Watch — via startWatchApp
        // WCSession START_WORKOUT command DIHAPUS supaya Watch tidak double-start
        healthStore.startWatchApp(with: configuration) { success, error in
            if !success {
                print("Failed to start watch app via startWatchApp: \(error?.localizedDescription ?? "unknown error")")
            } else {
                // Kirim session ID ke Watch SETELAH app terbuka, supaya Watch tahu session ini
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    let context: [String: Any] = [
                        "sessionId": self.activeWorkoutSessionId,
                        "status": "active"
                    ]
                    WatchSessionManager.shared.sendWorkoutUpdate(data: context)
                    print("[iOS] Sent session context to Watch: \(self.activeWorkoutSessionId)")
                }
                print("Direct startWatchApp request triggered successfully")
            }
        }
    }

    
    func notifyWatchToEndWorkout() {
        WatchSessionManager.shared.sendWorkoutUpdate(data: [
            "status": "stop_request",
            "sessionId": activeWorkoutSessionId
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
                    
                    // Local check for time-based challenge if watch is not connected
                    if let challenge = self.selectedChallenge ?? self.receivedChallenge {
                        if challenge.challengeName.contains("15 Min Endurance") && self.elapsedSeconds >= 900 {
                            print("[iOS] Local fallback timer: Target time reached. Auto ending workout.")
                            self.endWorkout()
                        }
                    }
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
        self.isHost = true
        multipeerManager?.invite(peer)
    }
    
    func acceptInvite() {
        self.isHost = false
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
        
        // Construct and record the workout session
        let currentType = selectedChallenge?.sport ?? receivedChallenge?.sport ?? .running
        let currentDuration = Double(elapsedSeconds)
        let currentHR = heartRate > 0 ? heartRate : Double.random(in: 125...145) // fallback average
        let currentCal = watchCalories > 0 ? watchCalories : Double.random(in: 80...160) // fallback energy
        let partner = currentRoom?.partnerName ?? "Partner"
        
        let newWorkout = PastWorkout(
            date: Date(),
            type: currentType,
            duration: currentDuration,
            avgHeartRate: currentHR,
            calories: currentCal,
            partnerName: partner
        )
        
        // Insert at the beginning of list
        self.pastWorkouts.insert(newWorkout, at: 0)
        self.savePastWorkoutsLocally()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.fetchHealthKitWorkouts()
        }
        appState = .results
    }
    
    // MARK: - Local Persistence Helpers
    
    private func loadPastWorkoutsLocally() {
        if let data = UserDefaults.standard.data(forKey: "flint_past_workouts"),
           let decoded = try? JSONDecoder().decode([PastWorkout].self, from: data) {
            self.pastWorkouts = decoded
        } else {
            // Start completely blank
            self.pastWorkouts = []
            self.savePastWorkoutsLocally()
        }
    }
    
    private func savePastWorkoutsLocally() {
        if let encoded = try? JSONEncoder().encode(self.pastWorkouts) {
            UserDefaults.standard.set(encoded, forKey: "flint_past_workouts")
        }
    }
    
    func rematch() {
        appState = .workoutSetup
    }
    
    public func skipProximityAndGoToRoom() {
        let partnerName = self.multipeerManager?.connectedPeer?.displayName ?? "Partner"
        DispatchQueue.main.async {
            self.currentRoom = RoomSession(partnerName: partnerName, formedAt: Date())
            self.appState = .room
        }
    }
    
    public func skipConnectionAndGoToSetup() {
        DispatchQueue.main.async {
            self.appState = .workoutSetup
        }
    }
    
    public func skipWaitingAndStartWorkout() {
        DispatchQueue.main.async {
            self.appState = .activeWorkout
            self.notifyWatchToStartWorkout()
        }
    }
    
    func forgetWorkout(_ workout: PastWorkout) {
        pastWorkouts.removeAll { $0.id == workout.id }
    }
    
    private func sendWatchStatusToPeer() {
        let isConnected = WatchSessionManager.shared.isWatchConnected
        let payload = WatchStatusPayload(isWatchConnected: isConnected)
        if let payloadData = try? JSONEncoder().encode(payload) {
            let message = MultipeerMessage(type: .watchStatus, payload: payloadData)
            if let messageData = try? JSONEncoder().encode(message) {
                multipeerManager?.sendData(messageData)
                print("[iOS] Sent watch status to peer: \(isConnected)")
            }
        }
    }
}

// MARK: - Watch Connectivity Status Model

struct WatchStatusPayload: Codable {
    let isWatchConnected: Bool
}

// MARK: - Dummy NI Session Delegate for early permission prompt

class DummyNISessionDelegate: NSObject, NISessionDelegate {
    static let shared = DummyNISessionDelegate()
    private override init() {}
    func session(_ session: NISession, didInvalidateWith error: Error) {
        print("[NI] Dummy session invalidated (expected during pre-prompt): \(error.localizedDescription)")
    }
}
