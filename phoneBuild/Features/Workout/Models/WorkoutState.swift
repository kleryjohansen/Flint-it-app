import Foundation
import MultipeerConnectivity

public enum AppState {
    case home               // Layar "Tap to find mates"
    case searching          // Animasi Radar
    case foundPartner       // Muncul profil partner
    case navigating         // Layar panah arah (Nearby Interaction)
    case workoutSetup       // Pilih olahraga & challenge
    case syncing            // Waiting / Countdown sinkronisasi
    case activeWorkout      // Dashboard olahraga berjalan
    case results            // Layar hasil akhir
    case room               // Workout Room Ready!
}

public enum WorkoutType: String, CaseIterable, Identifiable, Codable {
    case running = "Running"
    case cycling = "Cycling"
    case weightlifting = "Weightlifting"
    
    public var id: String { self.rawValue }
    
    // Helper untuk icon
    public var iconName: String {
        switch self {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .weightlifting: return "dumbbell.fill"
        }
    }
}

public struct IncomingInvite: Identifiable {
    public let id = UUID()
    public let peerID: MCPeerID
    public let handler: (Bool, MCSession?) -> Void
}

public struct PastWorkout: Identifiable, Codable {
    public var id = UUID()
    public let date: Date
    public let type: WorkoutType
    public let duration: TimeInterval
    public let avgHeartRate: Double
    public var calories: Double? = nil
    public var partnerName: String? = nil
}

public struct PeerInfo: Identifiable, Equatable {
    public let id: MCPeerID
    public var displayName: String { id.displayName }

    public static func == (lhs: PeerInfo, rhs: PeerInfo) -> Bool {
        lhs.id == rhs.id
    }
}

public struct RoomSession: Equatable {
    public let partnerName: String
    public let formedAt: Date
}

public struct WorkoutChallenge: Codable, Equatable {
    public let sport: WorkoutType
    public let goalValue: Double // e.g. 1.0 (km) or 100.0 (kcal)
    public let challengeName: String
    public let metricType: String // "distance" atau "calories"
}

// MARK: - Message Envelope
public struct MultipeerMessage: Codable {
    public enum MessageType: String, Codable {
        case text
        case niDiscoveryToken
        case niTokenACK  // Acknowledgment that peer received our token
        case sendChallenge // Sending a challenge
        case acceptChallenge // Accepting a challenge
        case endWorkout // Partner requested to end workout session
    }
    public let type: MessageType
    public let payload: Data
    
    public init(type: MessageType, payload: Data) {
        self.type = type
        self.payload = payload
    }
}
