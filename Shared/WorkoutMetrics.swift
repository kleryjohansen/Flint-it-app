import Foundation
import WatchConnectivity
import Combine

public struct WorkoutMetrics: Codable {
    public var heartRate: Double
    public var distance: Float?
    public var remainingSeconds: Int
    public var isWorkoutRunning: Bool
    public var calories: Double
    public var isDistanceMetric: Bool
    
    public init(heartRate: Double = 0.0, distance: Float? = nil, remainingSeconds: Int = 0, isWorkoutRunning: Bool = false, calories: Double = 0.0, isDistanceMetric: Bool = false) {
        self.heartRate = heartRate
        self.distance = distance
        self.remainingSeconds = remainingSeconds
        self.isWorkoutRunning = isWorkoutRunning
        self.calories = calories
        self.isDistanceMetric = isDistanceMetric
    }
}

public class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    public static let shared = WatchSessionManager()
    
    @Published public var workoutState: [String: Any] = [:]
    
    #if os(iOS)
    @Published public var heartRate: Double = 0.0
    @Published public var distance: Double = 0.0
    @Published public var isRunning: Bool = false
    #endif
    
    private var session: WCSession?
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    public func sendWorkoutUpdate(data: [String: Any]) {
        guard let session = session, session.activationState == .activated else { return }
        do {
            try session.updateApplicationContext(data)
            
            // Also send direct message for faster realtime delivery when reachable
            if session.isReachable {
                session.sendMessage(data, replyHandler: nil, errorHandler: nil)
            }
        } catch {
            print("[WatchSessionManager] Gagal update context: \(error)")
        }
    }

    // MARK: - WCSessionDelegate Methods
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[WatchSessionManager] WCSession activationState: \(activationState.rawValue)")
    }
    
    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleReceivedData(applicationContext)
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleReceivedData(message)
    }
    
    private func handleReceivedData(_ data: [String: Any]) {
        DispatchQueue.main.async {
            self.workoutState = data
            
            #if os(iOS)
            if let rawMetrics = data["metrics"] as? Data {
                if let metrics = try? JSONDecoder().decode(WorkoutMetrics.self, from: rawMetrics) {
                    self.heartRate = metrics.heartRate
                    if let dist = metrics.distance {
                        self.distance = Double(dist)
                    }
                    self.isRunning = metrics.isWorkoutRunning
                    return
                }
            }
            if let hr = data["heartRate"] as? Double {
                self.heartRate = hr
            }
            if let dist = data["distance"] as? Double {
                self.distance = dist
            }
            if let status = data["status"] as? String {
                if status == "stopped" {
                    self.isRunning = false
                } else if status == "active" {
                    self.isRunning = true
                }
            }
            #else
            // Sisi Watch (Apple Watch)
            if let status = data["status"] as? String {
                if status == "stop_request" {
                    WatchWorkoutService.shared.endWorkout()
                }
            }
            if let command = data["command"] as? String {
                if command == "START_WORKOUT" {
                    let sport = data["sport"] as? String ?? "Weightlifting"
                    WatchWorkoutService.shared.startWorkout(sport: sport)
                } else if command == "END_WORKOUT" {
                    WatchWorkoutService.shared.endWorkout()
                }
            }
            #endif
        }
    }
}
