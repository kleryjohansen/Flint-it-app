import Foundation
import MultipeerConnectivity
import NearbyInteraction
import WatchConnectivity
import UIKit
import Combine

class iOSConnectivityService: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, WCSessionDelegate {
    
    @Published var isPeerConnected = false
    @Published var watchMetrics = WorkoutMetrics()
    
    var onReceivedDiscoveryToken: ((NIDiscoveryToken) -> Void)?
    
    private let serviceType = "workout-pair"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    
    private var mcSession: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    var wcSession: WCSession?
    
    override init() {
        super.init()
        setupWatchConnectivity()
        setupMultipeer()
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
        }
    }
    
    private func setupMultipeer() {
        mcSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession?.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }
    
    func notifyWatchToStartWorkout() {
        guard let session = wcSession, session.isReachable else {
            print("Watch is not reachable")
            return
        }
        
        session.sendMessage(["command": "START_WORKOUT"], replyHandler: nil, errorHandler: { error in
            print("Error sending message to watch: \(error.localizedDescription)")
        })
    }
    
    func sendToken(_ token: NIDiscoveryToken) {
        guard let mcSession = mcSession, !mcSession.connectedPeers.isEmpty else { return }
        
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            try? mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
        }
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let data = message["metrics"] as? Data {
            if let metrics = try? JSONDecoder().decode(WorkoutMetrics.self, from: data) {
                DispatchQueue.main.async {
                    self.watchMetrics = metrics
                }
            }
        }
    }
    
    // MARK: - MCSessionDelegate
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.isPeerConnected = (state == .connected)
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
            onReceivedDiscoveryToken?(token)
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    
    // MARK: - MCNearbyServiceAdvertiserDelegate
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, mcSession)
    }
    
    // MARK: - MCNearbyServiceBrowserDelegate
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: mcSession!, withContext: nil, timeout: 10)
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
