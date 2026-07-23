import Foundation
import Combine
import NearbyInteraction
import MultipeerConnectivity
import HealthKit
import AVFoundation
import AudioToolbox
import UIKit


// MARK: - Room Participant

public enum ParticipantStatus {
    case connected
    case connecting
}

public struct RoomParticipant: Identifiable, Equatable {
    public let id: MCPeerID
    public var displayName: String
    public var status: ParticipantStatus

    public init(id: MCPeerID, displayName: String, status: ParticipantStatus) {
        self.id = id
        self.displayName = displayName
        self.status = status
    }
}


// MARK: - AudioManager Helper

class AudioManager: NSObject {
    static let shared = AudioManager()
    private var audioPlayer: AVAudioPlayer?
    
    override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func playVictory() {
        playSound(name: "winningSound")
    }
    
    func playDefeat() {
        playSound(name: "defeatSound")
    }
    
    func playSoloComplete() {
        playSound(name: "winningSound")
    }
    
    private func playSound(name: String) {
        if let asset = NSDataAsset(name: name) {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
                
                audioPlayer = try AVAudioPlayer(data: asset.data)
                audioPlayer?.numberOfLoops = 0
                audioPlayer?.volume = 1.0
                audioPlayer?.play()
                print("[iOS] Successfully playing sound asset: \(name)")
            } catch {
                print("[iOS] Error playing sound asset: \(error.localizedDescription)")
            }
        } else {
            print("[iOS] Sound asset not found in catalog: \(name)")
        }
    }
}

public enum ActiveAlert: Identifiable {
    case distanceDisconnect
    case rivalLeft
    case leaveConfirmation
    case rematchPrompt
    
    public var id: String {
        switch self {
        case .distanceDisconnect: return "distanceDisconnect"
        case .rivalLeft: return "rivalLeft"
        case .leaveConfirmation: return "leaveConfirmation"
        case .rematchPrompt: return "rematchPrompt"
        }
    }
}

public class iOSWorkoutViewModel: NSObject, ObservableObject {
    @Published public var activeAlert: ActiveAlert? = nil
    
    @Published var appState: AppState = .home {
        didSet {
            if appState == .activeWorkout {
                startCountdown()
            } else if appState == .home || appState == .results {
                stopLocalWorkoutTimer()
                stopRealTimeHealthKitQueries()
                stopCloudKitSyncTimer()
                stopRangeTickTimer()
            } else if appState == .searching {
                startCloudKitSyncTimer()
            } else {
                stopCloudKitSyncTimer()
            }
            if appState == .room {
                startRangeTickTimer()
            } else {
                stopRangeTickTimer()
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
    @Published public var roomParticipants: [RoomParticipant] = []
    @Published public var hostPeerID: MCPeerID?

    /// Convenience: peer pertama yang terkoneksi (untuk label UI 1v1)
    public var primaryConnectedPeer: MCPeerID? {
        multipeerManager?.connectedPeers.first
    }

    /// Convenience: nama display peer pertama yang terkoneksi
    public var primaryPartnerName: String {
        if let name = currentRoom?.partnerName { return name }
        return primaryConnectedPeer?.displayName ?? "Partner"
    }
    
    // Challenge states
    @Published public var selectedChallenge: WorkoutChallenge?
    @Published public var receivedChallenge: WorkoutChallenge?
    
    // Watch Connectivity
    @Published public var watchCalories: Double = 0.0
    @Published public var isHost: Bool = false
    @Published public var partnerWatchConnected: Bool = true
    
    // Workout Results and real-time syncing
    @Published public var partnerProgress: [MCPeerID: Double] = [:]
    @Published public var partnerDistance: [MCPeerID: Double] = [:]
    @Published public var partnerCalories: [MCPeerID: Double] = [:]
    
    @Published public var localProgress: Double = 0.0
    @Published public var localDistance: Double = 0.0
    @Published public var localCalories: Double = 0.0
    @Published public var localSteps: Double = 0.0
    @Published public var localSpeed: Double = 0.0
    @Published public var localElevation: Double = 0.0
    
    // Proximity logic properties
    @Published public var distances: [MCPeerID: Double] = [:]
    @Published public var profileImages: [MCPeerID: UIImage] = [:]
    @Published public var lastMessageTime: [MCPeerID: Date] = [:]
    @Published public var rangeTick: Date = Date()  // increments to retrigger range status UI
    
    public enum RangeStatus { case inRange, far, unknown }
    
    public func rangeStatus(for peerID: MCPeerID) -> RangeStatus {
        // Primary signal: NI distance (akurasi tinggi)
        if let d = distances[peerID] {
            if d < 2.0 { return .inRange }
            if d <= 8.0 { return .far }
            return .unknown
        }
        // Fallback: heartbeat proxy (untuk peer tanpa NI)
        guard let lastTime = lastMessageTime[peerID] else { return .unknown }
        let elapsed = Date().timeIntervalSince(lastTime)
        if elapsed < 3.0 { return .inRange }
        if elapsed <= 10.0 { return .far }
        return .unknown
    }
    @Published public var showDistanceWarning: Bool = false

    
    @Published public var partnerSteps: [MCPeerID: Double] = [:]
    @Published public var partnerSpeed: [MCPeerID: Double] = [:]
    @Published public var partnerElevation: [MCPeerID: Double] = [:]
    
    @Published public var avgPaceText: String = "--:--"
    @Published public var workoutResult: WorkoutResult = .solo
    @Published public var partnerFinalDistance: Double = 0.0
    @Published public var partnerFinalTime: Int = 0
    @Published public var partnerFinalCalories: Double = 0.0
    @Published public var peerProfiles: [String: PeerProfile] = [:]
    @Published public var peerResults: [String: WorkoutResultsPayload] = [:]
    
    private var cloudKitSyncTimer: Timer?
    private var isAheadOfPartner: Bool = false
    
    private var watchCancellables = Set<AnyCancellable>()
    
    // Session tracking — cegah stale "stopped" dari sesi sebelumnya
    private var activeWorkoutSessionId: String = ""
    private var workoutStartTime: Date?
    
    // HealthKit
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var caloriesQuery: HKAnchoredObjectQuery?
    
    @Published var pastWorkouts: [PastWorkout] = []
    @Published public var foundPeers: [PeerInfo] = []
    
    // Local Fallback Workout Timer
    private var activeWorkoutTimer: Timer?
    @Published public var elapsedSeconds: Int = 0
    private var lastWatchMessageTime: Date?
    
    // Workout start countdown
    @Published public var countdownSeconds: Int = -1
    private var countdownTimer: Timer?
    private var rangeTickTimer: Timer?
    
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
        
        let hasPresented = UserDefaults.standard.bool(forKey: "hasPresentedPermissions")
        if !hasPresented {
            requestAllPermissions()
        } else {
            if HKHealthStore.isHealthDataAvailable() {
                fetchHealthKitWorkouts()
            }
        }
    }
    
    private func setupWatchObserving() {
        WatchSessionManager.shared.$workoutState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                
                // Guard: hanya proses data jika workout sedang aktif di iOS
                guard self.appState == .activeWorkout else { return }
                
                let incomingSessionId = state["sessionId"] as? String ?? ""
                if !incomingSessionId.isEmpty && incomingSessionId != self.activeWorkoutSessionId {
                    print("[iOS] Ignoring stale data from previous watch session: \(incomingSessionId)")
                    return
                }
                
                if let hr = state["heartRate"] as? Double, hr > 0 {
                    self.heartRate = hr
                    self.lastWatchMessageTime = Date()
                }
                
                if let steps = state["steps"] as? Double {
                    self.localSteps = steps
                }
                if let speed = state["speed"] as? Double {
                    self.localSpeed = speed
                }
                if let elevation = state["elevation"] as? Double {
                    self.localElevation = elevation
                }
                
                let challenge = self.selectedChallenge ?? self.receivedChallenge
                let goalValue = challenge?.goalValue ?? 1.0
                let metricType = challenge?.metricType ?? "distance"
                let targetInUnits = metricType == "distance" ? (goalValue * 1000.0) : goalValue
                
                if let cal = state["calories"] as? Double, cal > 0 {
                    self.watchCalories = cal
                    self.localCalories = cal
                    self.lastWatchMessageTime = Date()
                    
                    if metricType == "calories" {
                        self.localProgress = targetInUnits > 0 ? min(cal / targetInUnits, 1.0) : 0.0
                        self.sendProgressToPartner(value: cal, ratio: self.localProgress, pace: 0.0)
                        
                        // Check target calories
                        if cal >= goalValue {
                            print("[iOS] Target calories reached (\(cal) / \(goalValue) kcal) — auto ending workout")
                            self.endWorkout()
                        }
                    }
                }
                
                if let dist = state["distance"] as? Double, dist > 0 {
                    self.localDistance = dist
                    self.lastWatchMessageTime = Date()
                    
                    self.avgPaceText = self.calculateAveragePace(distanceMeters: dist, elapsedSeconds: self.elapsedSeconds)
                    
                    if metricType == "distance" {
                        if challenge?.challengeName.contains("Endurance") == true {
                            self.localProgress = min(Double(self.elapsedSeconds) / 900.0, 1.0)
                        } else {
                            self.localProgress = targetInUnits > 0 ? min(dist / targetInUnits, 1.0) : 0.0
                        }
                        self.sendProgressToPartner(value: dist, ratio: self.localProgress, pace: 0.0)
                        
                        // Check target distance
                        if challenge?.challengeName.contains("Endurance") == false {
                            if dist >= targetInUnits {
                                print("[iOS] Target distance reached (\(dist) / \(targetInUnits)m) — auto ending workout")
                                self.endWorkout()
                            }
                        }
                    }
                }

                if let secs = state["remainingSeconds"] as? Int, secs > 0 {
                    self.formatCountdownText(seconds: secs)
                    self.elapsedSeconds = secs
                    self.lastWatchMessageTime = Date()
                    
                    if challenge?.challengeName.contains("Endurance") == true {
                        self.localProgress = min(Double(secs) / 900.0, 1.0)
                        self.sendProgressToPartner(value: self.localDistance, ratio: self.localProgress, pace: 0.0)
                        
                        if secs >= 900 {
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
                if self.primaryConnectedPeer != nil {
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
                self?.requestLocalNetworkPermission {
                    UserDefaults.standard.set(true, forKey: "hasPresentedPermissions")
                }
            }
        }
    }
    
    private func requestNearbyInteractionPermission(completion: @escaping () -> Void) {
        guard NISession.deviceCapabilities.supportsDirectionMeasurement || NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
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
    
    private func requestLocalNetworkPermission(completion: @escaping () -> Void = {}) {
        // Start multipeer browsing briefly to trigger Local Network dialog
        multipeerManager?.startBrowsing()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.appState != .searching {
                self.multipeerManager?.stopBrowsing()
            }
            completion()
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
        var userName = UserDefaults.standard.string(forKey: "savedUsername") ?? ""
        if userName.isEmpty {
            userName = "Athlete"
        }

        // Reset state
        hasSentOwnToken = false
        pendingPeerToken = nil
        hasReceivedPeerToken = false
        hasSentTokenACK = false

        var discoveryInfo: [String: String] = [:]
        if let image = loadProfileImageFromDisk(),
           let profileBase64 = makeDiscoveryProfileImageBase64(from: image) {
            discoveryInfo["pic"] = profileBase64
        }

        let manager = MultipeerManager(customDisplayName: userName, discoveryInfo: discoveryInfo)
        self.multipeerManager = manager

        manager.onFoundPeersChanged = { [weak self] peers in
            DispatchQueue.main.async {
                self?.foundPeers = peers
            }
        }

        manager.onDataReceived = { [weak self] type, payload, peerID in
            guard let self = self else { return }
            // Heartbeat: track kapan terakhir kita terima message dari peer ini
            self.lastMessageTime[peerID] = Date()
            switch type {
            case .niDiscoveryToken:
                self.handlePeerTokenReceived(payload)
            case .niTokenACK:
                self.handlePeerACK()
            case .sendChallenge:
                if let challenge = try? JSONDecoder().decode(WorkoutChallenge.self, from: payload) {
                    DispatchQueue.main.async {
                        self.receivedChallenge = challenge
                        // Auto-start workout — guest already agreed to host's room
                        self.appState = .activeWorkout
                        self.notifyWatchToStartWorkout()
                    }
                }
            case .acceptChallenge:
                DispatchQueue.main.async {
                    self.appState = .activeWorkout
                    self.notifyWatchToStartWorkout()
                }
            case .rematchRequest:
                DispatchQueue.main.async {
                    self.activeAlert = .rematchPrompt
                }
            case .acceptRematch:
                DispatchQueue.main.async {
                    self.goToRematchSetup()
                }
            case .profilePhoto:
                if let image = UIImage(data: payload) {
                    DispatchQueue.main.async {
                        self.profileImages[peerID] = image
                    }
                }
            case .profileExchange:
                if let profile = try? JSONDecoder().decode(PeerProfile.self, from: payload) {
                    DispatchQueue.main.async {
                        self.peerProfiles[peerID.displayName] = profile
                        if let data = profile.profileImageData,
                           let image = UIImage(data: data) {
                            self.profileImages[peerID] = image
                        }
                    }
                }
            case .endWorkout:
                DispatchQueue.main.async {
                    self.endWorkoutNatively()
                }
            case .joinRoom:
                DispatchQueue.main.async {
                    guard self.appState == .navigating || self.appState == .searching || self.appState == .workoutSetup else { return }
                    let partnerName = self.primaryConnectedPeer?.displayName ?? self.primaryPartnerName
                    self.currentRoom = RoomSession(partnerName: partnerName, formedAt: Date())
                    self.appState = .room
                    print("[iOS] Received joinRoom broadcast — entering room")
                }
            case .workoutResults:
                if let payloadObj = try? JSONDecoder().decode(WorkoutResultsPayload.self, from: payload) {
                    DispatchQueue.main.async {
                        self.peerResults[peerID.displayName] = payloadObj
                        self.partnerFinalDistance = payloadObj.distance
                        self.partnerFinalTime = payloadObj.elapsedSeconds
                        self.partnerFinalCalories = payloadObj.calories
                    }
                }
            case .peerLeftRoom:
                DispatchQueue.main.async {
                    self.activeAlert = .rivalLeft
                    self.fullCleanup()
                    self.appState = .home
                }
            case .watchStatus:
                if let payloadObj = try? JSONDecoder().decode(WatchStatusPayload.self, from: payload) {
                    DispatchQueue.main.async {
                        self.partnerWatchConnected = payloadObj.isWatchConnected
                        print("[iOS] Received watch status from partner: \(payloadObj.isWatchConnected)")
                    }
                }
            case .workoutProgress:
                if let payloadObj = try? JSONDecoder().decode(WorkoutProgressPayload.self, from: payload) {
                    DispatchQueue.main.async {
                        self.partnerProgress[peerID] = payloadObj.progressRatio
                        let challenge = self.selectedChallenge ?? self.receivedChallenge
                        if challenge?.metricType == "distance" {
                            self.partnerDistance[peerID] = payloadObj.progressValue
                        } else {
                            self.partnerCalories[peerID] = payloadObj.progressValue
                        }
                        
                        self.partnerSteps[peerID] = payloadObj.steps
                        self.partnerSpeed[peerID] = payloadObj.speed
                        self.partnerElevation[peerID] = payloadObj.elevation
                        
                        let ownGoal = challenge?.goalValue ?? 1.0
                        let targetVal = (challenge?.metricType == "distance") ? (ownGoal * 1000.0) : ownGoal
                        let ownProgressVal = (challenge?.metricType == "distance") ? self.localDistance : self.localCalories
                        let ownRatio = targetVal > 0 ? min(ownProgressVal / targetVal, 1.0) : 0.0
                        
                        // Cek status khusus progress rival primer untuk passing notif
                        if peerID == self.primaryConnectedPeer {
                            self.checkPassingStatus(localProgress: ownRatio, partnerProgress: payloadObj.progressRatio)
                        }
                    }
                }
            default:
                break
            }
        }

        manager.onPeerConnecting = { [weak self] peerID in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let idx = self.roomParticipants.firstIndex(where: { $0.id == peerID }) {
                    self.roomParticipants[idx].status = .connecting
                } else {
                    self.roomParticipants.append(
                        RoomParticipant(id: peerID, displayName: peerID.displayName, status: .connecting)
                    )
                }
            }
        }

        manager.onPeerConnected = { [weak self] peerID in
            guard let self = self else { return }
            // Reset state on new connection
            self.hasSentOwnToken = false
            self.pendingPeerToken = nil
            self.hasReceivedPeerToken = false
            self.hasSentTokenACK = false

            // Auto-lock when room reaches 7 guests (8 total with host)
            if self.isHost && self.roomParticipants.count >= 7 {
                self.multipeerManager?.lockRoom()
            }

            DispatchQueue.main.async {
                if let idx = self.roomParticipants.firstIndex(where: { $0.id == peerID }) {
                    self.roomParticipants[idx].status = .connected
                    self.roomParticipants[idx].displayName = peerID.displayName
                } else {
                    self.roomParticipants.append(
                        RoomParticipant(id: peerID, displayName: peerID.displayName, status: .connected)
                    )
                }

                if self.isHost {
                    if self.appState == .room || self.appState == .workoutSetup {
                        self.broadcastJoinRoom()
                    } else {
                        self.appState = .navigating
                    }
                } else {
                    // kalau ini peer pertama kita connect dengan, dia host kita
                    if self.hostPeerID == nil {
                        self.hostPeerID = peerID
                        self.isHost = false
                    }
                    // Guest: stop discovery begitu masuk room
                    self.multipeerManager?.stopAll()
                    self.appState = .navigating
                }
            }

            // Send our token
            self.sendLocalNIToken()

            // Send our watch connection status to the peer
            self.sendWatchStatusToPeer()

            // Send our profile photo to the peer
            self.sendProfilePhotoToPeer()
            self.sendProfileToAll()
        }

        niManager.onProximityUpdate = { [weak self] distance in
            guard let self = self else { return }
            
            // Sync live distance to Watch
            self.syncDistanceToWatch(Float(distance))
            
            DispatchQueue.main.async {
                // NI 1:1 — update distance for the primary partner only.
                // For additional guests, distances[peerID] stays nil (red dot).
                if let primary = self.primaryConnectedPeer {
                    self.distances[primary] = distance
                }
                
                // If the user has already entered the lobby/workout session
                // Proximity distance check is ONLY active in the lobby (.room) before the match starts!
                if self.appState == .room {
                    if distance < 2.0 {
                        self.showDistanceWarning = false
                    } else if distance >= 3.0 && distance <= 8.0 {
                        self.showDistanceWarning = true
                    } else if distance > 8.0 {
                        self.showDistanceWarning = false
                        self.activeAlert = .distanceDisconnect
                        
                        // Automatically disconnect and go back to home
                        self.fullCleanup()
                        self.appState = .home
                    }
                } else if self.appState == .navigating {
                    // Not in the lobby yet: if they get < 2.0 meters, enter the lobby
                    if distance < 2.0 {
                        let partnerName = self.primaryPartnerName
                        self.currentRoom = RoomSession(partnerName: partnerName, formedAt: Date())
                        self.appState = .room
                        if self.isHost {
                            self.broadcastJoinRoom()
                        }
                    }
                } else {
                    // During active workout or other screens, they can go as far as they want!
                    self.showDistanceWarning = false
                }
            }
        }

        manager.onPeerDisconnected = { [weak self] peerID in
            guard let self = self else { return }
            // Reset token exchange state
            self.hasSentOwnToken = false
            self.pendingPeerToken = nil
            self.hasReceivedPeerToken = false
            self.hasSentTokenACK = false

            DispatchQueue.main.async {
                // Hapus participant dari room
                self.roomParticipants.removeAll { $0.id == peerID }
                // Cleanup per-peer state
                self.distances.removeValue(forKey: peerID)
                self.profileImages.removeValue(forKey: peerID)
                self.lastMessageTime.removeValue(forKey: peerID)
                self.partnerProgress.removeValue(forKey: peerID)
                self.partnerDistance.removeValue(forKey: peerID)
                self.partnerCalories.removeValue(forKey: peerID)
                self.partnerSteps.removeValue(forKey: peerID)
                self.partnerSpeed.removeValue(forKey: peerID)
                self.partnerElevation.removeValue(forKey: peerID)

                if self.isHost {
                    // Host: stay di room, tetap advertising agar device lain bisa masuk
                    if self.roomParticipants.count < 7 {
                        self.multipeerManager?.startAdvertising()
                    }
                } else {
                    // Guest: jika host pergi, cleanup total
                    if peerID == self.hostPeerID || self.roomParticipants.isEmpty {
                        self.isHost = false
                        self.hostPeerID = nil
                        self.currentRoom = nil
                        self.roomParticipants = []
                        self.partnerWatchConnected = true
                        self.distances.removeAll()
                        self.profileImages.removeAll()
                        self.lastMessageTime.removeAll()
                        self.partnerProgress.removeAll()
                        self.partnerDistance.removeAll()
                        self.partnerCalories.removeAll()
                        self.partnerSteps.removeAll()
                        self.partnerSpeed.removeAll()
                        self.partnerElevation.removeAll()
                        self.appState = .home
                    }
                }
            }
        }
    }

    private func makeDiscoveryProfileImageBase64(from image: UIImage) -> String? {
        let targetSize = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let smallImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let jpegData = smallImage.jpegData(compressionQuality: 0.1) else {
            return nil
        }

        let base64 = jpegData.base64EncodedString()
        return base64.count < 350 ? base64 : nil
    }
    
    // MARK: - Token Exchange Handshake

    private func sendLocalNIToken() {
        guard primaryConnectedPeer != nil else {
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
        guard primaryConnectedPeer != nil, !hasSentTokenACK else { return }
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

    public func leaveLobby() {
        let connectedCount = multipeerManager?.session.connectedPeers.count ?? 0
        if connectedCount == 1 {
            // Exactly 2 people (Host + 1 Guest). Send peerLeftRoom notification to the rival
            let message = MultipeerMessage(type: .peerLeftRoom, payload: Data())
            if let data = try? JSONEncoder().encode(message) {
                multipeerManager?.sendData(data)
            }
        }
        
        fullCleanup()
        appState = .home
    }

    /// Single entry point untuk cleanup. Dipanggil dari View.
    /// idempotent — aman dipanggil berkali-kali.
    public func fullCleanup() {
        // 1. Reset NI session (ini akan invalidate dan buat session baru)
        niManager.reset()

        // 2. Reset Multipeer fully so stale session data does not carry over.
        multipeerManager?.fullReset()

        // 3. Clear room state
        currentRoom = nil
        selectedChallenge = nil
        receivedChallenge = nil
        watchCalories = 0.0
        partnerFinalDistance = 0.0
        partnerFinalTime = 0
        partnerFinalCalories = 0.0
        peerResults.removeAll()
        partnerProgress.removeAll()
        partnerDistance.removeAll()
        partnerCalories.removeAll()
        partnerSteps.removeAll()
        partnerSpeed.removeAll()
        partnerElevation.removeAll()
        appState = .home

        print("[ViewModel] Full cleanup done")
    }

    private func broadcastJoinRoom() {
        let message = MultipeerMessage(type: .joinRoom, payload: Data())
        if let data = try? JSONEncoder().encode(message) {
            multipeerManager?.sendData(data)
        }
    }

    private func sendProfileToAll() {
        let ownName = UserDefaults.standard.string(forKey: "savedUsername") ?? "Player"
        let ownPicData = loadProfileImageFromDisk()?.jpegData(compressionQuality: 0.7)
        let profile = PeerProfile(displayName: ownName, profileImageData: ownPicData)

        if let encoded = try? JSONEncoder().encode(profile) {
            let message = MultipeerMessage(type: .profileExchange, payload: encoded)
            if let messageData = try? JSONEncoder().encode(message) {
                multipeerManager?.sendData(messageData)
            }
        }
    }

    public func getProfileImage(for displayName: String) -> UIImage? {
        if let exchanged = peerProfiles[displayName],
           let data = exchanged.profileImageData {
            return UIImage(data: data)
        }

        if let found = multipeerManager?.foundPeers.first(where: { $0.displayName == displayName }),
           let base64 = found.profileImageBase64,
           let data = Data(base64Encoded: base64) {
            return UIImage(data: data)
        }

        return nil
    }

    public struct ContestantResult: Identifiable {
        public var id: String { name }
        public let name: String
        public let time: Int
        public let progressValue: Double
        public let image: UIImage?
        public let isHost: Bool
    }

    public var allContestantResults: [ContestantResult] {
        var list: [ContestantResult] = []
        let challenge = selectedChallenge ?? receivedChallenge
        let ownName = UserDefaults.standard.string(forKey: "savedUsername") ?? "You"
        let ownPic = loadProfileImageFromDisk()

        list.append(
            ContestantResult(
                name: ownName,
                time: elapsedSeconds,
                progressValue: challenge?.metricType == "distance" ? localDistance : localCalories,
                image: ownPic,
                isHost: isHost
            )
        )

        let connectedPeers = multipeerManager?.connectedPeers ?? []
        for peer in connectedPeers {
            let stats = peerResults[peer.displayName]
            let peerValue = challenge?.metricType == "distance"
                ? (stats?.distance ?? partnerDistance[peer] ?? 0.0)
                : (stats?.calories ?? partnerCalories[peer] ?? 0.0)

            list.append(
                ContestantResult(
                    name: peer.displayName,
                    time: stats?.elapsedSeconds ?? elapsedSeconds,
                    progressValue: peerValue,
                    image: getProfileImage(for: peer.displayName),
                    isHost: false
                )
            )
        }

        return list.sorted {
            if $0.time == 0 { return false }
            if $1.time == 0 { return true }
            return $0.time < $1.time
        }
    }

    // MARK: - Challenge Functions
    
    public func sendChallenge(_ challenge: WorkoutChallenge) {
        if multipeerManager?.connectedPeers.isEmpty ?? true {
            self.selectedChallenge = challenge
            self.workoutResult = .solo
            self.appState = .activeWorkout
            notifyWatchToStartWorkout()
        } else {
            if let encoded = try? JSONEncoder().encode(challenge) {
                let message = MultipeerMessage(type: .sendChallenge, payload: encoded)
                if let messageData = try? JSONEncoder().encode(message) {
                    multipeerManager?.sendData(messageData)
                    self.selectedChallenge = challenge
                    // Auto-start workout for host too — challenge applies to everyone in room
                    self.appState = .activeWorkout
                    notifyWatchToStartWorkout()
                    // Host: lock discovery setelah broadcast
                    if self.isHost {
                        self.multipeerManager?.lockRoom()
                    }
                }
            }
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
            "sessionId": activeWorkoutSessionId,
            "result": workoutResult.rawValue
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
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownSeconds = -1
    }
    
    private func startCountdown() {
        // Reset timers and countdown state
        activeWorkoutTimer?.invalidate()
        activeWorkoutTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        
        elapsedSeconds = 0
        heartRate = 0.0
        watchCalories = 0.0
        lastWatchMessageTime = nil
        formatCountdownText(seconds: 0)
        localProgress = 0.0
        localDistance = 0.0
        localCalories = 0.0
        localSteps = 0.0
        localSpeed = 0.0
        localElevation = 0.0
        
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
                    
                    // Actually start workout tracking
                    self.startLocalWorkoutTimer()
                    self.startRealTimeHealthKitQueries()
                    self.startCloudKitSyncTimer()
                } else {
                    self.countdownSeconds = -1
                    self.countdownTimer?.invalidate()
                    self.countdownTimer = nil
                }
            }
        }
    }
    
    private func triggerCountdownHaptic(isFinal: Bool) {
        #if os(iOS)
        if isFinal {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        }
        #endif
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
    
    var roomIdentifier: String {
        let ownName = UserDefaults.standard.string(forKey: "savedUsername") ?? "Player1"
        let partnerName = currentRoom?.partnerName ?? "Player2"
        let sorted = [ownName, partnerName].sorted()
        return "\(sorted[0])_\(sorted[1])"
    }

    public func endWorkout() {
        if primaryConnectedPeer == nil {
            self.workoutResult = .solo
            AudioManager.shared.playSoloComplete()
        } else {
            self.workoutResult = .victory
            AudioManager.shared.playVictory()
        }
        sendEndWorkoutCommandToPartner()
        endWorkoutNatively()
    }
    
    private func sendEndWorkoutCommandToPartner() {
        let message = MultipeerMessage(type: .endWorkout, payload: Data())
        if let messageData = try? JSONEncoder().encode(message) {
            multipeerManager?.sendData(messageData)
        }
        
        let roomID = self.roomIdentifier
        Task {
            let targetValue = self.selectedChallenge?.goalValue ?? self.receivedChallenge?.goalValue ?? 1.0
            let metricType = self.selectedChallenge?.metricType ?? self.receivedChallenge?.metricType ?? "distance"
            let _ = metricType == "distance" ? (targetValue * 1000.0) : targetValue
            let localVal = metricType == "distance" ? localDistance : localCalories
            await CloudKitService.shared.updateWorkoutProgress(
                roomID: roomID,
                isHost: self.isHost,
                progressValue: localVal,
                progressRatio: 1.0,
                seconds: self.elapsedSeconds,
                isFinished: true
            )
        }
    }
    
    private func endWorkoutNatively() {
        if primaryConnectedPeer != nil && self.workoutResult != .victory {
            self.workoutResult = .defeat
            AudioManager.shared.playDefeat()
        }
        
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
            partnerName: partner,
            isVictory: self.workoutResult == .victory || self.workoutResult == .solo
        )
        
        // Insert at the beginning of list
        self.pastWorkouts.insert(newWorkout, at: 0)
        self.savePastWorkoutsLocally()
        self.broadcastWorkoutResults(calories: currentCal)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.fetchHealthKitWorkouts()
        }
        appState = .results
    }

    private func broadcastWorkoutResults(calories: Double) {
        let payload = WorkoutResultsPayload(
            senderResult: workoutResult.rawValue,
            distance: localDistance,
            elapsedSeconds: elapsedSeconds,
            calories: calories,
            steps: localSteps
        )

        if let encoded = try? JSONEncoder().encode(payload) {
            let message = MultipeerMessage(type: .workoutResults, payload: encoded)
            if let messageData = try? JSONEncoder().encode(message) {
                multipeerManager?.sendData(messageData)
            }
        }
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
    
    public func sendRematchRequest() {
        print("[iOS] Sending rematch request to partner...")
        let message = MultipeerMessage(type: .rematchRequest, payload: Data())
        if let encoded = try? JSONEncoder().encode(message) {
            multipeerManager?.sendData(encoded)
        }
    }
    
    public func acceptRematchRequest() {
        print("[iOS] Accepting rematch request and notifying partner...")
        let message = MultipeerMessage(type: .acceptRematch, payload: Data())
        if let encoded = try? JSONEncoder().encode(message) {
            multipeerManager?.sendData(encoded)
        }
        goToRematchSetup()
    }
    
    private func goToRematchSetup() {
        DispatchQueue.main.async {
            self.activeAlert = nil
            // Reset active workout metrics
            self.partnerProgress.removeAll()
            self.partnerDistance.removeAll()
            self.partnerCalories.removeAll()
            self.partnerFinalDistance = 0.0
            self.partnerFinalTime = 0
            self.partnerFinalCalories = 0.0
            self.peerResults.removeAll()
            self.partnerSteps.removeAll()
            self.partnerSpeed.removeAll()
            self.partnerElevation.removeAll()
            self.watchCalories = 0.0
            self.heartRate = 0.0
            self.countdownText = "00:00"
            self.countdownSeconds = -1
            self.localDistance = 0.0
            self.localCalories = 0.0
            self.localProgress = 0.0
            self.localSteps = 0.0
            self.localSpeed = 0.0
            self.localElevation = 0.0
            self.elapsedSeconds = 0
            self.selectedChallenge = nil
            self.receivedChallenge = nil
            self.workoutResult = .solo
            
            // Route based on role: host goes to workoutSetup, guest goes to room formed
            self.appState = self.isHost ? .workoutSetup : .room
        }
    }
    
    public func skipProximityAndGoToRoom() {
        let partnerName = self.primaryPartnerName
        DispatchQueue.main.async {
            self.currentRoom = RoomSession(partnerName: partnerName, formedAt: Date())
            self.appState = .room
        }
    }
    
    public func skipConnectionAndGoToSetup() {
        DispatchQueue.main.async {
            self.appState = .workoutSetup
            if self.isHost {
                self.multipeerManager?.lockRoom()
            }
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

    private func sendProfilePhotoToPeer() {
        guard let image = loadProfileImageFromDisk(),
              let jpegData = image.jpegData(compressionQuality: 0.7) else { return }
        let message = MultipeerMessage(type: .profilePhoto, payload: jpegData)
        if let messageData = try? JSONEncoder().encode(message) {
            multipeerManager?.sendData(messageData)
            print("[iOS] Sent profile photo (\(jpegData.count) bytes) to peer")
        }
    }
    
    // MARK: - Workout Pacing and Synchronization Helpers
    
    func calculateAveragePace(distanceMeters: Double, elapsedSeconds: Int) -> String {
        guard distanceMeters > 5 else { return "--:--" }
        let distanceKm = distanceMeters / 1000.0
        let paceSecondsPerKm = Double(elapsedSeconds) / distanceKm
        let minutes = Int(paceSecondsPerKm) / 60
        let seconds = Int(paceSecondsPerKm) % 60
        if minutes > 99 { return "--:--" }
        return String(format: "%d:%02d /km", minutes, seconds)
    }
    
    func sendProgressToPartner(value: Double, ratio: Double, pace: Double) {
        let payload = WorkoutProgressPayload(
            progressValue: value,
            progressRatio: ratio,
            currentPace: pace,
            steps: self.localSteps,
            speed: self.localSpeed,
            elevation: self.localElevation
        )
        if let encoded = try? JSONEncoder().encode(payload) {
            let message = MultipeerMessage(type: .workoutProgress, payload: encoded)
            if let messageData = try? JSONEncoder().encode(message) {
                multipeerManager?.sendData(messageData)
            }
        }
        
        let roomID = self.roomIdentifier
        Task {
            await CloudKitService.shared.updateWorkoutProgress(
                roomID: roomID,
                isHost: self.isHost,
                progressValue: value,
                progressRatio: ratio,
                seconds: self.elapsedSeconds,
                isFinished: ratio >= 1.0,
                steps: self.localSteps,
                speed: self.localSpeed,
                elevation: self.localElevation
            )
        }
    }
    
    private func checkPassingStatus(localProgress: Double, partnerProgress: Double) {
        guard localProgress > 0 || partnerProgress > 0 else { return }
        
        if localProgress > partnerProgress {
            if !isAheadOfPartner {
                isAheadOfPartner = true
                sendHapticToWatch(type: "success")
            }
        } else if localProgress < partnerProgress {
            isAheadOfPartner = false
        }
    }
    
    private func sendHapticToWatch(type: String) {
        let data: [String: Any] = ["haptic": type]
        WatchSessionManager.shared.sendWorkoutUpdate(data: data)
    }
    
    // MARK: - CloudKit Sync Loops
    
    private func startCloudKitSyncTimer() {
        cloudKitSyncTimer?.invalidate()
        cloudKitSyncTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.performCloudKitSync()
        }
    }
    
    private func stopCloudKitSyncTimer() {
        cloudKitSyncTimer?.invalidate()
        cloudKitSyncTimer = nil
    }

    private func startRangeTickTimer() {
        stopRangeTickTimer()
        rangeTickTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.rangeTick = Date()
        }
    }

    private func stopRangeTickTimer() {
        rangeTickTimer?.invalidate()
        rangeTickTimer = nil
    }
    
    private func performCloudKitSync() {
        let ownName = UserDefaults.standard.string(forKey: "savedUsername") ?? "Player"
        
        if appState == .searching {
            Task {
                await CloudKitService.shared.registerSearchingStatus(username: ownName, isSearching: true)
                let searchers = await CloudKitService.shared.fetchOnlineSearchers(excludeUsername: ownName)
                
                DispatchQueue.main.async {
                    for searcher in searchers {
                        let mockPeer = MCPeerID(displayName: "[Cloud] " + searcher)
                        self.multipeerManager?.addMockPeer(mockPeer)
                    }
                }
                
                if let invite = await CloudKitService.shared.checkPendingInternetInvite(for: ownName) {
                    DispatchQueue.main.async {
                        let mockPeer = MCPeerID(displayName: "[Cloud] " + invite.from)
                        self.multipeerManager?.setPendingInvite(mockPeer)
                    }
                }
            }
        }
        
        if let invited = multipeerManager?.invitedPeer, invited.displayName.hasPrefix("[Cloud] ") {
            let toUsername = invited.displayName.replacingOccurrences(of: "[Cloud] ", with: "")
            Task {
                if await CloudKitService.shared.isInternetInviteAccepted(to: toUsername) {
                    DispatchQueue.main.async {
                        self.multipeerManager?.setConnectedPeer(invited)
                        self.skipProximityAndGoToRoom()
                    }
                }
            }
        }
        
        if appState == .activeWorkout {
            let targetValue = self.selectedChallenge?.goalValue ?? self.receivedChallenge?.goalValue ?? 1.0
            let metricType = self.selectedChallenge?.metricType ?? self.receivedChallenge?.metricType ?? "distance"
            let targetInUnits = metricType == "distance" ? (targetValue * 1000.0) : targetValue
            let localVal = metricType == "distance" ? localDistance : localCalories
            let localRatio = targetInUnits > 0 ? min(localVal / targetInUnits, 1.0) : 0.0
            
            Task {
                let roomID = self.roomIdentifier
                await CloudKitService.shared.updateWorkoutProgress(
                    roomID: roomID,
                    isHost: self.isHost,
                    progressValue: localVal,
                    progressRatio: localRatio,
                    seconds: self.elapsedSeconds,
                    isFinished: localRatio >= 1.0,
                    steps: self.localSteps,
                    speed: self.localSpeed,
                    elevation: self.localElevation
                )
                
                if let workoutData = try? await CloudKitService.shared.fetchWorkoutData(roomID: roomID) {
                    DispatchQueue.main.async {
                        if let peerID = self.primaryConnectedPeer {
                            if self.isHost {
                                self.partnerProgress[peerID] = workoutData.guestProgressRatio
                                self.partnerDistance[peerID] = workoutData.guestProgressValue
                                self.partnerCalories[peerID] = workoutData.guestProgressValue
                                self.partnerSteps[peerID] = workoutData.guestSteps
                                self.partnerSpeed[peerID] = workoutData.guestSpeed
                                self.partnerElevation[peerID] = workoutData.guestElevation
                                if workoutData.guestFinished && self.appState == .activeWorkout {
                                    self.endWorkoutNatively()
                                }
                            } else {
                                self.partnerProgress[peerID] = workoutData.hostProgressRatio
                                self.partnerDistance[peerID] = workoutData.hostProgressValue
                                self.partnerCalories[peerID] = workoutData.hostProgressValue
                                self.partnerSteps[peerID] = workoutData.hostSteps
                                self.partnerSpeed[peerID] = workoutData.hostSpeed
                                self.partnerElevation[peerID] = workoutData.hostElevation
                                if workoutData.hostFinished && self.appState == .activeWorkout {
                                    self.endWorkoutNatively()
                                }
                            }
                        }
                        
                        let challenge = self.selectedChallenge ?? self.receivedChallenge
                        let ownGoal = challenge?.goalValue ?? 1.0
                        let isDistance = challenge?.metricType == "distance"
                        let targetVal = isDistance ? (ownGoal * 1000.0) : ownGoal
                        let ownProgressVal = isDistance ? self.localDistance : self.localCalories
                        let ownRatio = targetVal > 0 ? min(ownProgressVal / targetVal, 1.0) : 0.0
                        if let peerID = self.primaryConnectedPeer,
                           let rivalProgress = self.partnerProgress[peerID] {
                            self.checkPassingStatus(localProgress: ownRatio, partnerProgress: rivalProgress)
                        }
                    }
                }
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
