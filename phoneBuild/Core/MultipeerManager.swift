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

    public let peerID: MCPeerID
    public let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser

    // SwiftUI-observed state
    public private(set) var foundPeers: [PeerInfo] = [] {
        didSet {
            onFoundPeersChanged?(foundPeers)
        }
    }
    public private(set) var connectedPeer: MCPeerID?
    public private(set) var pendingInvitingPeer: MCPeerID?
    public private(set) var invitedPeer: MCPeerID?
    public private(set) var isAdvertising = false
    public private(set) var isBrowsing = false
    public private(set) var browserState: MultipeerBrowserState = .idle
    public private(set) var permissionState: MultipeerPermissionState = .unknown

    @ObservationIgnored private var currentRetryCount = 0
    @ObservationIgnored private var pendingInvitationHandler: ((Bool, MCSession?) -> Void)?

    @ObservationIgnored public var onPeerConnected: ((MCPeerID) -> Void)?
    @ObservationIgnored public var onPeerDisconnected: (() -> Void)?
    @ObservationIgnored public var onDataReceived: ((MultipeerMessage.MessageType, Data, MCPeerID) -> Void)?
    @ObservationIgnored public var onFoundPeersChanged: (([PeerInfo]) -> Void)?

    // MARK: - Init

    public init(customDisplayName: String) {
        self.peerID = MCPeerID(displayName: customDisplayName)
        self.session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .none
        )
        self.advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        self.browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)

        super.init()

        self.session.delegate = self
        self.advertiser.delegate = self
        self.browser.delegate = self

        // Auto-advertise — device selalu bisa ditemukan
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
                self.setConnectedPeer(peer)
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
    
    public func setConnectedPeer(_ peer: MCPeerID) {
        self.connectedPeer = peer
        self.invitedPeer = nil
        self.stopAll()
        self.onPeerConnected?(peer)
    }

    // MARK: - Data Sending

    public func sendData(_ data: Data) {
        guard !session.connectedPeers.isEmpty else {
            print("[MP] Cannot send: no connected peers")
            return
        }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            print("[MP] Sent \(data.count) bytes")
        } catch {
            print("[MP] Send error: \(error.localizedDescription)")
        }
    }

    // MARK: - Disconnect

    public func disconnect() {
        session.disconnect()
        stopAll()
        DispatchQueue.main.async {
            self.connectedPeer = nil
            self.invitedPeer = nil
            self.foundPeers.removeAll()
        }
        print("[MP] Disconnected")
    }
}

// MARK: - Browser Delegate

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let peerInfo = PeerInfo(id: peerID)
        DispatchQueue.main.async {
            if !self.foundPeers.contains(peerInfo) {
                self.foundPeers.append(peerInfo)
                self.browserState = .scanning // Still scanning, but found peers
                print("[MP] Found peer: \(peerID.displayName)")
            }
        }
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.foundPeers.removeAll { $0.id == peerID }
            print("[MP] Lost peer: \(peerID.displayName)")

            // If no peers left after losing one, update state
            if self.foundPeers.isEmpty {
                self.browserState = .noPeersFound
            }
        }
    }

    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        let nsError = error as NSError

        print("[MP] Browse error: \(error.localizedDescription)")
        print("[MP] Error domain: \(nsError.domain), code: \(nsError.code)")

        // Update permission state based on error
        if nsError.code == -72008 || nsError.code == -72002 {
            // -72008: Permission denied / Local network access denied
            // -72002: Service unavailable
            DispatchQueue.main.async {
                self.permissionState = .denied
                self.browserState = .permissionNeeded
            }
        } else if nsError.code == -72003 {
            // -72003: Network is restricted
            DispatchQueue.main.async {
                self.permissionState = .restricted
                self.browserState = .permissionNeeded
            }
        } else {
            // Other errors - try retry with backoff
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

    /// Check and update permission state by attempting a probe
    public func checkPermissionState() {
        // Stop any existing browse to do a clean check
        let wasBrowsing = isBrowsing
        if isBrowsing {
            browser.stopBrowsingForPeers()
        }

        // Attempt to start browsing briefly to trigger permission prompt
        browser.startBrowsingForPeers()

        // Stop after a short delay - we just want to trigger the permission dialog
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.browser.stopBrowsingForPeers()
            if wasBrowsing {
                self?.startBrowsing()
            }
        }
    }

    /// Reset permission state to unknown (e.g., after user returns from Settings)
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
                let wasConnected = self.connectedPeer == peerID
                if wasConnected { self.connectedPeer = nil }
                if self.invitedPeer == peerID { self.invitedPeer = nil }
                self.foundPeers.removeAll { $0.id == peerID }
                if wasConnected { self.onPeerDisconnected?() }
            }

        case .connecting:
            print("[MP] Connecting to: \(peerID.displayName)")

        case .connected:
            print("[MP] Connected to: \(peerID.displayName)")
            DispatchQueue.main.async {
                self.connectedPeer = peerID
                self.invitedPeer = nil
                // Stop semua — handshake selesai
                self.stopAll()
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
