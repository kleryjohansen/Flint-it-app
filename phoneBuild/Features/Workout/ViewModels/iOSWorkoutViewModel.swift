import Foundation
import Combine
import NearbyInteraction
import MultipeerConnectivity

public class iOSWorkoutViewModel: NSObject, ObservableObject {
    @Published var appState: AppState = .home
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
    
    // Simulation Countdown State
    @Published public var searchCountdown: Int = 3
    private var simulationTimer: AnyCancellable?
    
    @Published var pastWorkouts: [PastWorkout] = [
        PastWorkout(date: Date().addingTimeInterval(-86400 * 2), type: .weightlifting, duration: 2400, avgHeartRate: 135.0),
        PastWorkout(date: Date().addingTimeInterval(-86400 * 5), type: .running, duration: 1800, avgHeartRate: 155.0)
    ]
    
    // Token exchange state
    private var hasSentOwnToken = false
    private var pendingPeerToken: Data?
    private var hasReceivedPeerToken = false
    private var hasSentTokenACK = false
    
    public override init() {
        super.init()
        setupMultipeerManager()
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
            
            // Cancel simulation timer if a real peer connects
            self.simulationTimer?.cancel()
            
            // Saat peer terkoneksi, ubah appState = .navigating
            DispatchQueue.main.async {
                self.appState = .navigating
            }
            
            // Send our token
            self.sendLocalNIToken()
        }

        niManager.onProximityUpdate = { [weak self] distance in
            guard let self = self else { return }
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
    
    // MARK: - Simulation Helper
    
    public func startSearching() {
        appState = .searching
        multipeerManager?.startBrowsing()
        
        searchCountdown = 3
        simulationTimer?.cancel()
        simulationTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.searchCountdown > 1 {
                    self.searchCountdown -= 1
                } else {
                    self.simulationTimer?.cancel()
                    // Set up simulated partner
                    let partnerName = "Erling Antetokounmpo"
                    self.currentRoom = RoomSession(partnerName: partnerName, formedAt: Date())
                    // Directly skip searching and go to workoutSetup!
                    self.appState = .workoutSetup
                }
            }
    }
    
    public func stopSearching() {
        appState = .home
        multipeerManager?.stopSearching()
        simulationTimer?.cancel()
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
        appState = .home
        simulationTimer?.cancel()

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
        }
    }
    
    public func declineChallenge() {
        self.receivedChallenge = nil
        self.appState = .workoutSetup
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
    }
    
    func endWorkout() {
        appState = .results
    }
    
    func rematch() {
        appState = .workoutSetup
    }
    
    func forgetWorkout(_ workout: PastWorkout) {
        pastWorkouts.removeAll { $0.id == workout.id }
    }
}
