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
}

public enum WorkoutType: String, CaseIterable, Identifiable {
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

public struct PastWorkout: Identifiable {
    public let id = UUID()
    public let date: Date
    public let type: WorkoutType
    public let duration: TimeInterval
    public let avgHeartRate: Double
}
