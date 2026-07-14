import Foundation
import NearbyInteraction
import simd
import Observation

@Observable
public final class NearbyInteractionManager: NSObject {

    // MARK: - State (SwiftUI-observed, all mutations must be on main thread)

    public private(set) var distance: Double?
    public private(set) var direction: simd_float3?
    public private(set) var arrowAngleDegrees: Double = 0
    public private(set) var isSessionActive = false
    public private(set) var peerIsOutOfRange = false
    public private(set) var errorMessage: String?

    // MARK: - Callbacks (wired by iOSWorkoutViewModel)

    @ObservationIgnored public var onProximityUpdate: ((Double) -> Void)?

    // MARK: - Private

    @ObservationIgnored private var session: NISession?
    @ObservationIgnored private var isConfiguring = false  // Guard against double-configure race

    public override init() {
        super.init()
        setupSession()
    }

    // MARK: - Session Setup

    private func setupSession() {
        let newSession = NISession()
        newSession.delegate = self
        self.session = newSession
        print("[NI] New NISession created")
    }

    // MARK: - Token Exchange

    /// Archive local discovery token for sending via Multipeer.
    /// NIDiscoveryToken is available immediately after NISession init — no async needed.
    public func localTokenData() -> Data? {
        guard let token = session?.discoveryToken else {
            print("[NI] No discovery token available")
            return nil
        }
        return try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    /// Called when peer's token arrives via Multipeer (runs on background thread — safe).
    public func handleReceivedToken(_ data: Data) {
        guard !isConfiguring else {
            print("[NI] Already configuring, ignoring token")
            return
        }

        guard let token = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self,
            from: data
        ) else {
            print("[NI] Failed to unarchive received token")
            return
        }

        guard let session else {
            print("[NI] No active session to run")
            return
        }

        isConfiguring = true
        let config = NINearbyPeerConfiguration(peerToken: token)
        session.run(config)

        // isSessionActive is @Observable — must update on main thread
        DispatchQueue.main.async {
            self.isSessionActive = true
            self.errorMessage = nil
            self.isConfiguring = false
        }
        print("[NI] Session started with peer token")
    }

    // MARK: - Reset + Retry

    /// Invalidates current session, creates a new one, then triggers token re-exchange.
    public func reset() {
        session?.invalidate()
        session = nil
        isConfiguring = false

        // Clear all state on main thread
        DispatchQueue.main.async {
            self.distance = nil
            self.direction = nil
            self.arrowAngleDegrees = 0
            self.isSessionActive = false
            self.peerIsOutOfRange = false
            self.errorMessage = nil
        }

        setupSession()
        print("[NI] Session reset complete")
    }

    // MARK: - Arrow Angle

    private func calculateArrowAngle(from direction: simd_float3) -> Double {
        // direction.x = horizontal (positive = right)
        // direction.z = depth (negative = in front, ARKit/NI convention)
        let angle = atan2(Double(direction.x), Double(-direction.z))
        return angle * (180.0 / .pi)
    }
}

// MARK: - NISessionDelegate

extension NearbyInteractionManager: NISessionDelegate {

    public func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let obj = nearbyObjects.first else { return }

        let validDistance: Double? = obj.distance.map { Double($0) }
        let newDirection = obj.direction

        if let d = validDistance {
            print("[NI] Distance: \(String(format: "%.1f", d))m | direction: \(newDirection != nil ? "yes" : "no (no UWB)")")
        }

        DispatchQueue.main.async {
            // Always clear out-of-range when we get a fresh update
            self.peerIsOutOfRange = false
            self.distance = validDistance
            self.direction = newDirection

            if let dir = newDirection {
                self.arrowAngleDegrees = self.calculateArrowAngle(from: dir)
            }

            if let dist = validDistance {
                self.onProximityUpdate?(dist)
            }
        }
    }

    public func session(_ session: NISession, didInvalidateWith error: Error) {
        print("[NI] Session invalidated: \(error.localizedDescription)")

        let message: String
        if let niError = error as? NIError {
            switch niError.code {
            case .invalidConfiguration:
                message = "Configuration error. Tap to retry."
            case .sessionFailed:
                message = "Session failed. Tap to retry."
            case .resourceUsageTimeout:
                message = "Session timed out. Tap to retry."
            case .unsupportedPlatform:
                message = "Nearby Interaction not supported on this device."
            case .activeSessionsLimitExceeded:
                message = "Too many active sessions. Tap to retry."
            default:
                message = "Session error. Tap to retry."
            }
        } else {
            message = "Session error. Tap to retry."
        }

        DispatchQueue.main.async {
            self.isSessionActive = false
            self.distance = nil
            self.direction = nil
            self.arrowAngleDegrees = 0
            self.peerIsOutOfRange = false
            self.errorMessage = message
        }
    }

    public func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], with reason: NINearbyObject.RemovalReason) {
        switch reason {
        case .timeout:
            // Peer went out of range — keep session alive, it auto-resumes
            print("[NI] Peer out of range (timeout) — session kept alive")
            DispatchQueue.main.async {
                self.distance = nil
                self.direction = nil
                self.arrowAngleDegrees = 0
                self.peerIsOutOfRange = true
                // isSessionActive stays true — session is still valid
            }

        case .peerEnded:
            // Peer explicitly called invalidate() — clean up
            print("[NI] Peer ended session intentionally")
            DispatchQueue.main.async {
                self.isSessionActive = false
                self.distance = nil
                self.direction = nil
                self.arrowAngleDegrees = 0
                self.peerIsOutOfRange = false
            }

        @unknown default:
            break
        }
    }
}
