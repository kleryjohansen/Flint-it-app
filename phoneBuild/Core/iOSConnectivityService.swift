import Foundation
import MultipeerConnectivity
import NearbyInteraction
import WatchConnectivity
import UIKit
import Combine

class iOSConnectivityService: NSObject, ObservableObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, WCSessionDelegate {
    
    @Published var isPeerConnected = false
    @Published var watchMetrics = WorkoutMetrics()
    
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var incomingInvite: IncomingInvite?
    
    var onReceivedDiscoveryToken: ((NIDiscoveryToken) -> Void)?
    var onReceivedWorkoutStart: (() -> Void)?
    var onReceivedWorkoutEnd: (() -> Void)?
    
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
    }
    
    func startBrowsing() {
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        
        advertiser?.startAdvertisingPeer()
        discoveredPeers.removeAll()
    }
    
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
    }
    
    func invitePeer(_ peerID: MCPeerID) {
        guard let mcSession = mcSession else { return }
        browser?.invitePeer(peerID, to: mcSession, withContext: nil, timeout: 15)
    }
    
    func acceptInvite() {
        if let invite = incomingInvite {
            invite.handler(true, mcSession)
        }
        incomingInvite = nil
    }
    
    func declineInvite() {
        if let invite = incomingInvite {
            invite.handler(false, nil)
        }
        incomingInvite = nil
    }
    
    func disconnect() {
        mcSession?.disconnect()
        isPeerConnected = false
        discoveredPeers.removeAll()
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
    
    func notifyPeerToStartWorkout() {
        guard let mcSession = mcSession, !mcSession.connectedPeers.isEmpty else { return }
        let message = ["command": "START_WORKOUT"]
        if let data = try? JSONEncoder().encode(message) {
            try? mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
        }
    }
    
    func notifyPeerToEndWorkout() {
        guard let mcSession = mcSession, !mcSession.connectedPeers.isEmpty else { return }
        let message = ["command": "END_WORKOUT"]
        if let data = try? JSONEncoder().encode(message) {
            try? mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
        }
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
        // First try decoding as a token
        if let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
            onReceivedDiscoveryToken?(token)
            return
        }
        
        // Then try decoding as a dictionary message
        if let message = try? JSONDecoder().decode([String: String].self, from: data) {
            if message["command"] == "START_WORKOUT" {
                DispatchQueue.main.async {
                    self.onReceivedWorkoutStart?()
                }
            } else if message["command"] == "END_WORKOUT" {
                DispatchQueue.main.async {
                    self.onReceivedWorkoutEnd?()
                }
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    
    // MARK: - MCNearbyServiceAdvertiserDelegate
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            self.incomingInvite = IncomingInvite(peerID: peerID, handler: invitationHandler)
        }
    }
    
    // MARK: - MCNearbyServiceBrowserDelegate
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0 == peerID }
        }
    }
}
