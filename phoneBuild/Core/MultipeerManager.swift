import Foundation
import MultipeerConnectivity
import Observation

// MARK: - MultipeerManager

@Observable
public final class MultipeerManager: NSObject {
    private let serviceType = "fit-challenge"

    public let peerID: MCPeerID
    public let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser

    // SwiftUI-observed state
    public private(set) var foundPeers: [PeerInfo] = []
    public private(set) var connectedPeer: MCPeerID?
    public private(set) var pendingInvitingPeer: MCPeerID?
    public private(set) var invitedPeer: MCPeerID?
    public private(set) var isAdvertising = false
    public private(set) var isBrowsing = false

    @ObservationIgnored private var pendingInvitationHandler: ((Bool, MCSession?) -> Void)?

    @ObservationIgnored public var onPeerConnected: ((MCPeerID) -> Void)?
    @ObservationIgnored public var onPeerDisconnected: (() -> Void)?
    @ObservationIgnored public var onDataReceived: ((MultipeerMessage.MessageType, Data, MCPeerID) -> Void)?

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
        print("[MP] Started browsing")
    }

    public func stopBrowsing() {
        browser.stopBrowsingForPeers()
        isBrowsing = false
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
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        DispatchQueue.main.async {
            self.invitedPeer = peerID
        }
        print("[MP] Invite sent to: \(peerID.displayName)")
    }

    // MARK: - Invitation Response

    public func acceptInvitation() {
        guard let handler = pendingInvitationHandler else { return }
        handler(true, session)
        pendingInvitationHandler = nil
        DispatchQueue.main.async { self.pendingInvitingPeer = nil }
        print("[MP] Invitation accepted")
    }

    public func declineInvitation() {
        guard let handler = pendingInvitationHandler else { return }
        handler(false, nil)
        pendingInvitationHandler = nil
        DispatchQueue.main.async { self.pendingInvitingPeer = nil }
        print("[MP] Invitation declined")
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
                print("[MP] Found peer: \(peerID.displayName)")
            }
        }
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.foundPeers.removeAll { $0.id == peerID }
            print("[MP] Lost peer: \(peerID.displayName)")
        }
    }

    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("[MP] Browse error: \(error.localizedDescription)")
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
            case .niDiscoveryToken:
                print("[MP] Received NI token from \(peerID.displayName)")
                onDataReceived?(.niDiscoveryToken, message.payload, peerID)
            case .niTokenACK:
                print("[MP] Received token ACK from \(peerID.displayName)")
                onDataReceived?(.niTokenACK, message.payload, peerID)
            }
        } else if let text = String(data: data, encoding: .utf8) {
            print("[MP] Legacy text from \(peerID.displayName): \(text)")
        }
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
