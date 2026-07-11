import Foundation
import Combine
import NearbyInteraction

class iOSWorkoutViewModel: NSObject, ObservableObject, NISessionDelegate {
    @Published var heartRate: Double = 0.0
    @Published var countdownText: String = "00:00"
    @Published var distanceToPeer: Float? = nil
    
    @Published var connectivityService = iOSConnectivityService()
    
    private var cancellables = Set<AnyCancellable>()
    private var niSession: NISession?
    
    override init() {
        super.init()
        
        connectivityService.$watchMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.heartRate = metrics.heartRate
                self?.formatCountdownText(seconds: metrics.remainingSeconds)
            }
            .store(in: &cancellables)
            
        connectivityService.onReceivedDiscoveryToken = { [weak self] token in
            self?.startNISession(with: token)
        }
    }
    
    private func formatCountdownText(seconds: Int) {
        let mins = seconds / 60
        let secs = seconds % 60
        self.countdownText = String(format: "%02d:%02d", mins, secs)
    }
    
    private func startNISession(with token: NIDiscoveryToken) {
        niSession = NISession()
        niSession?.delegate = self
        
        // Share our token back
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
