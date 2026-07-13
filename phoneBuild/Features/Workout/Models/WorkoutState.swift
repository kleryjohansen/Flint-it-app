import Foundation
import MultipeerConnectivity

public enum AppState {
    case discovery
    case workoutSelection
    case connected
    case activeWorkout
    case results
    case profile
}

public enum WorkoutType: String, CaseIterable, Identifiable {
    case functionalStrengthTraining = "Functional Strength Training"
    case running = "Running"
    case cycling = "Cycling"
    
    public var id: String { self.rawValue }
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
