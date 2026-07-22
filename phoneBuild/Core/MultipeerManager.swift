import Foundation
import MultipeerConnectivity
import Observation

// MARK: - MultipeerPermissionState

public enum MultipeerPermissionState: Equatable {
    case unknown
    case permitted
    case denied
    case restricted
}

// MARK: - MultipeerBrowserState

public enum MultipeerBrowserState: Equatable {
    case idle
    case scanning
    case noPeersFound
    case permissionNeeded
    case error(String)
}

// MARK: - MultipeerManager

@Observable
public final class MultipeerManager: NSObject {
    private let serviceType = "fit-challenge"
    private let maxRetryAttempts = 3
    private let retryDelayBase: TimeInterval = 1.0
    private let maxPeers = 8

    public let peerID: MCPeerID
    public let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser

    // SwiftUI-observed state
    public private(set) var foundPeers: [PeerInfo] = []

    /// All currently-connected peers (up to 8). Use this instead of the old `connectedPeer`.
    public private(set) var connectedPeers: [MCPeerID] = []

    /// Backward-compat convenience: first connected peer, or nil.
    public var primaryConnectedPeer: MCPeerID? { connectedPeers.first }

    /// Legacy alias kept so existing call-sites still compile.
    public var connectedPeer: MCPeerID? { primaryConnectedPeer }

    public private(set) var pendingInvitingPeer: MCPeerID?
    public private(set) var invitedPeer: MCPeerID?
    public private(set) var isAdvertising = false
    public private(set) var isBrowsing = false
    public private(set) var browserState: MultipeerBrowserState = .idle
    public private(set) var permissionState: MultipeerPermissionState = .unknown

    @ObservationIgnored private var currentRetryCount = 0
    @ObservationIgnored private var pendingInvitationHandler: ((Bool, MCSession?) -> Void)?

    @ObservationIgnored public var onPeerConnected: ((MCPeerID) -> Void)?
    /// Now provides the specific peer that disconnected.
    @ObservationIgnored public var onPeerDisconnected: ((MCPeerID) -> Void)?
    @ObservationIgnored public var onDataReceived: ((MultipeerMessage.MessageType, Data, MCPeerID) -> Void)?

    // MARK: - Init

    public init(customDisplayName: String, discoveryInfo: [String: String]? = nil) {
        self.peerID = MCPeerID(displayName: customDisplayName)
        self.session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .none
        )
        self.advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        self.browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)

        super.init()

        self.session.delegate = self
        self.advertiser.delegate = self
        self.browser.delegate = self

        // Always advertise so others can find us
        startAdvertising()
    }

    // MARK: - Discovery Controls

    public func startAdvertising() {
        guard !isAdvertising else { return }
        advertiser.startAdvertisingPeer()
        isAdvertising = true
        print("[MP] Started advertising as: \(peerID.displayName)")
    }

    public func stopAdvertising() {
        advertiser.stopAdvertisingPeer()
        isAdvertising = false
        print("[MP] Stopped advertising")
    }

    public func startBrowsing() {
        guard !isBrowsing else { return }
        browser.startBrowsingForPeers()
        isBrowsing = true
        browserState = .scanning
        currentRetryCount = 0
        print("[MP] Started browsing")
    }

    public func stopBrowsing() {
        browser.stopBrowsingForPeers()
        isBrowsing = false
        browserState = .idle
        DispatchQueue.main.async {
            self.foundPeers.removeAll()
        }
        print("[MP] Stopped browsing")
    }

    public func stopSearching() {
        stopBrowsing()
    }

    public func stopAll() {
        stopAdvertising()
        stopBrowsing()
    }

    // MARK: - Full Reset
    /// Completely tears down and rebuilds advertising/browsing state so no stale
    /// session data carries over to the next match. Call this on fullCleanup().
    public func fullReset() {
        stopAll()
        session.disconnect()
        DispatchQueue.main.async {
            self.connectedPeers.removeAll()
            self.invitedPeer = nil
            self.pendingInvitingPeer = nil
            self.foundPeers.removeAll()
        }
        // Re-start advertising so we are discoverable again
        startAdvertising()
        print("[MP] Full reset complete")
    }

    // MARK: - Manual Invite

    public func invite(_ peerID: MCPeerID) {
        if peerID.displayName.hasPrefix("[Cloud] ") {
            let toUsername = peerID.displayName.replacingOccurrences(of: "[Cloud] ", with: "")
            let ownUsername = UserDefaults.standard.string(forKey: "savedUsername") ?? "Player"
            Task {
                await CloudKitService.shared.sendInternetInvite(from: ownUsername, to: toUsername)
            }
            DispatchQueue.main.async {
                self.invitedPeer = peerID
            }
        } else {
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
            DispatchQueue.main.async {
                self.invitedPeer = peerID
            }
        }
        print("[MP] Invite sent to: \(peerID.displayName)")
    }

    // MARK: - Invitation Response

    public func acceptInvitation() {
        if let peer = pendingInvitingPeer, peer.displayName.hasPrefix("[Cloud] ") {
            let fromUsername = peer.displayName.replacingOccurrences(of: "[Cloud] ", with: "")
            Task {
                await CloudKitService.shared.acceptInternetInvite(from: fromUsername)
            }
            DispatchQueue.main.async {
                self.addConnectedPeer(peer)
            }
        } else {
            guard let handler = pendingInvitationHandler else { return }
            handler(true, session)
            pendingInvitationHandler = nil
            DispatchQueue.main.async { self.pendingInvitingPeer = nil }
        }
        print("[MP] Invitation accepted")
    }

    public func declineInvitation() {
        if let peer = pendingInvitingPeer, peer.displayName.hasPrefix("[Cloud] ") {
            DispatchQueue.main.async { self.pendingInvitingPeer = nil }
        } else {
            guard let handler = pendingInvitationHandler else { return }
            handler(false, nil)
            pendingInvitationHandler = nil
            DispatchQueue.main.async { self.pendingInvitingPeer = nil }
        }
        print("[MP] Invitation declined")
    }
    
    // MARK: - Internet Mock Peer Helpers
    
    public func addMockPeer(_ peer: MCPeerID) {
        let peerInfo = PeerInfo(id: peer)
        if !foundPeers.contains(peerInfo) {
            foundPeers.append(peerInfo)
        }
    }
    
    public func setPendingInvite(_ peer: MCPeerID) {
        self.pendingInvitingPeer = peer
    }
    
    /// Called when a cloud-based invite is accepted (no MPC handshake).
    public func setConnectedPeer(_ peer: MCPeerID) {
        addConnectedPeer(peer)
        self.invitedPeer = nil
        self.stopAll()
        self.onPeerConnected?(peer)
    }

    // MARK: - Data Sending

    /// Send data to ALL connected peers.
    public func sendData(_ data: Data) {
        let peers = session.connectedPeers
        guard !peers.isEmpty else {
            print("[MP] Cannot send: no connected peers")
            return
        }
        do {
            try session.send(data, toPeers: peers, with: .reliable)
            print("[MP] Sent \(data.count) bytes to \(peers.count) peer(s)")
        } catch {
            print("[MP] Send error: \(error.localizedDescription)")
        }
    }

    /// Send data to a specific subset of peers.
    public func sendData(_ data: Data, to peers: [MCPeerID]) {
        guard !peers.isEmpty else { return }
        do {
            try session.send(data, toPeers: peers, with: .reliable)
        } catch {
            print("[MP] Targeted send error: \(error.localizedDescription)")
        }
    }

    // MARK: - Disconnect

    public func disconnect() {
        session.disconnect()
        stopAll()
        DispatchQueue.main.async {
            self.connectedPeers.removeAll()
            self.invitedPeer = nil
            self.foundPeers.removeAll()
        }
        print("[MP] Disconnected")
    }

    // MARK: - Private Helpers

    private func addConnectedPeer(_ peer: MCPeerID) {
        guard !connectedPeers.contains(peer), connectedPeers.count < maxPeers else { return }
        connectedPeers.append(peer)
        invitedPeer = nil
        print("[MP] Added peer to room: \(peer.displayName) (total: \(connectedPeers.count))")
    }

    private func removeConnectedPeer(_ peer: MCPeerID) {
        connectedPeers.removeAll { $0 == peer }
        print("[MP] Removed peer from room: \(peer.displayName) (remaining: \(connectedPeers.count))")
    }
}

// MARK: - Browser Delegate

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let picBase64 = info?["pic"]
        let peerInfo = PeerInfo(id: peerID, profileImageBase64: picBase64)
        DispatchQueue.main.async {
            if !self.foundPeers.contains(peerInfo) {
                self.foundPeers.append(peerInfo)
                self.browserState = .scanning
                print("[MP] Found peer: \(peerID.displayName)")
            }
        }
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.foundPeers.removeAll { $0.id == peerID }
            print("[MP] Lost peer: \(peerID.displayName)")
            if self.foundPeers.isEmpty {
                self.browserState = .noPeersFound
            }
        }
    }

    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        let nsError = error as NSError
        print("[MP] Browse error: \(error.localizedDescription)")
        print("[MP] Error domain: \(nsError.domain), code: \(nsError.code)")

        if nsError.code == -72008 || nsError.code == -72002 {
            DispatchQueue.main.async {
                self.permissionState = .denied
                self.browserState = .permissionNeeded
            }
        } else if nsError.code == -72003 {
            DispatchQueue.main.async {
                self.permissionState = .restricted
                self.browserState = .permissionNeeded
            }
        } else {
            DispatchQueue.main.async {
                self.handleBrowseError(error)
            }
        }
    }

    private func handleBrowseError(_ error: Error) {
        guard currentRetryCount < maxRetryAttempts else {
            browserState = .error(error.localizedDescription)
            isBrowsing = false
            return
        }

        currentRetryCount += 1
        let delay = retryDelayBase * pow(2.0, Double(currentRetryCount - 1))
        print("[MP] Retry attempt \(currentRetryCount)/\(maxRetryAttempts) in \(delay)s")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.isBrowsing == false else { return }
            print("[MP] Retrying browse...")
            self.browser.startBrowsingForPeers()
        }
    }

    public func checkPermissionState() {
        let wasBrowsing = isBrowsing
        if isBrowsing { browser.stopBrowsingForPeers() }
        browser.startBrowsingForPeers()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.browser.stopBrowsingForPeers()
            if wasBrowsing { self?.startBrowsing() }
        }
    }

    public func resetPermissionState() {
        permissionState = .unknown
        browserState = .idle
        currentRetryCount = 0
    }
}

// MARK: - Advertiser Delegate

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        print("[MP] Received invitation from: \(peerID.displayName)")
        self.pendingInvitationHandler = invitationHandler
        DispatchQueue.main.async {
            self.pendingInvitingPeer = peerID
        }
    }

    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("[MP] Advertise error: \(error.localizedDescription)")
        DispatchQueue.main.async { self.isAdvertising = false }
    }
}

// MARK: - Session Delegate

extension MultipeerManager: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .notConnected:
            print("[MP] Disconnected from: \(peerID.displayName)")
            DispatchQueue.main.async {
                self.removeConnectedPeer(peerID)
                if self.invitedPeer == peerID { self.invitedPeer = nil }
                self.foundPeers.removeAll { $0.id == peerID }
                self.onPeerDisconnected?(peerID)
            }

        case .connecting:
            print("[MP] Connecting to: \(peerID.displayName)")

        case .connected:
            print("[MP] Connected to: \(peerID.displayName) — room now has \(session.connectedPeers.count) peer(s)")
            DispatchQueue.main.async {
                self.addConnectedPeer(peerID)
                // NOTE: We intentionally do NOT call stopAll() here.
                // Keeping advertising alive lets a 3rd, 4th... peer join the same session.
                self.onPeerConnected?(peerID)
            }

        @unknown default:
            print("[MP] Unknown state for: \(peerID.displayName)")
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = try? JSONDecoder().decode(MultipeerMessage.self, from: data) {
            switch message.type {
            case .text:
                if let text = String(data: message.payload, encoding: .utf8) {
                    print("[MP] Text from \(peerID.displayName): \(text)")
                }
            default:
                onDataReceived?(message.type, message.payload, peerID)
            }
        } else if let text = String(data: data, encoding: .utf8) {
            print("[MP] Legacy text from \(peerID.displayName): \(text)")
        }
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
