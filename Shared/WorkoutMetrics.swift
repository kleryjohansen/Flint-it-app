import Foundation

public struct WorkoutMetrics: Codable {
    public var heartRate: Double
    public var distance: Float?
    public var remainingSeconds: Int
    public var isWorkoutRunning: Bool
    
    public init(heartRate: Double = 0.0, distance: Float? = nil, remainingSeconds: Int = 0, isWorkoutRunning: Bool = false) {
        self.heartRate = heartRate
        self.distance = distance
        self.remainingSeconds = remainingSeconds
        self.isWorkoutRunning = isWorkoutRunning
    }
}
