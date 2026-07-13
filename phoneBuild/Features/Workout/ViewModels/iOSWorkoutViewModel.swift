import Foundation
import Combine
import NearbyInteraction
import MultipeerConnectivity

class iOSWorkoutViewModel: NSObject, ObservableObject, NISessionDelegate {
    @Published var appState: AppState = .discovery
    @Published var selectedWorkoutType: WorkoutType = .functionalStrengthTraining
    @Published var isChallengeMode: Bool = false
    
    @Published var heartRate: Double = 0.0
    @Published var countdownText: String = "00:00"
    @Published var distanceToPeer: Float? = nil
    
    @Published var connectivityService = iOSConnectivityService()
    
    @Published var pastWorkouts: [PastWorkout] = [
        PastWorkout(date: Date().addingTimeInterval(-86400 * 2), type: .functionalStrengthTraining, duration: 2400, avgHeartRate: 135.0),
        PastWorkout(date: Date().addingTimeInterval(-86400 * 5), type: .running, duration: 1800, avgHeartRate: 155.0)
    ]
    
    private var cancellables = Set<AnyCancellable>()
    private var niSession: NISession?
    
    override init() {
        super.init()
        
        // Start browsing automatically on init for discovery
        connectivityService.startBrowsing()
        
        connectivityService.$watchMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.heartRate = metrics.heartRate
                self?.formatCountdownText(seconds: metrics.remainingSeconds)
            }
            .store(in: &cancellables)
            
        connectivityService.$isPeerConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                guard let self = self else { return }
                if connected {
                    if self.appState == .discovery {
                        self.appState = .workoutSelection
                        self.connectivityService.stopBrowsing()
                    }
                } else {
                    if self.appState == .connected || self.appState == .workoutSelection {
                        self.appState = .discovery
                        self.connectivityService.startBrowsing()
                    }
                }
            }
            .store(in: &cancellables)
            
        connectivityService.onReceivedDiscoveryToken = { [weak self] token in
            self?.startNISession(with: token)
        }
        
        connectivityService.onReceivedWorkoutStart = { [weak self] in
            self?.transitionToWorkout()
        }
        
        connectivityService.onReceivedWorkoutEnd = { [weak self] in
            self?.endWorkout()
        }
    }
    
    func invite(peer: MCPeerID) {
        connectivityService.invitePeer(peer)
    }
    
    func acceptInvite() {
        connectivityService.acceptInvite()
    }
    
    func declineInvite() {
        connectivityService.declineInvite()
    }
    
    func proceedToConnected() {
        appState = .connected
    }
    
    func startWorkout() {
        connectivityService.notifyPeerToStartWorkout()
        transitionToWorkout()
    }
    
    private func transitionToWorkout() {
        appState = .activeWorkout
        connectivityService.notifyWatchToStartWorkout()
    }
    
    func endWorkout() {
        appState = .results
    }
    
    func stopWorkoutFromButton() {
        connectivityService.notifyPeerToEndWorkout()
        endWorkout()
    }
    
    func rematch() {
        appState = .workoutSelection
    }
    
    func addFriend() {
        print("Added friend!")
    }
    
    func forgetWorkout(_ workout: PastWorkout) {
        pastWorkouts.removeAll { $0.id == workout.id }
    }
    
    func compareWorkout(_ workout: PastWorkout) {
        print("Comparing workout \(workout.id)")
    }
    
    private func formatCountdownText(seconds: Int) {
        let mins = seconds / 60
        let secs = seconds % 60
        self.countdownText = String(format: "%02d:%02d", mins, secs)
    }
    
    private func startNISession(with token: NIDiscoveryToken) {
        niSession = NISession()
        niSession?.delegate = self
        
        if let myToken = niSession?.discoveryToken {
            connectivityService.sendToken(myToken)
        }
        
        let config = NINearbyPeerConfiguration(peerToken: token)
        niSession?.run(config)
    }
    
    // MARK: - NISessionDelegate
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        if let peer = nearbyObjects.first {
            DispatchQueue.main.async {
                self.distanceToPeer = peer.distance
            }
        }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        DispatchQueue.main.async {
            self.distanceToPeer = nil
        }
    }
}
