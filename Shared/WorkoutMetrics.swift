import Foundation
import WatchConnectivity
import Combine
#if canImport(WatchKit)
import WatchKit
#endif

public struct WorkoutMetrics: Codable {
    public var heartRate: Double
    public var distance: Float?
    public var remainingSeconds: Int
    public var isWorkoutRunning: Bool
    public var calories: Double
    public var isDistanceMetric: Bool
    public var steps: Double
    public var speed: Double
    public var elevation: Double
    
    public init(heartRate: Double = 0.0, distance: Float? = nil, remainingSeconds: Int = 0, isWorkoutRunning: Bool = false, calories: Double = 0.0, isDistanceMetric: Bool = false, steps: Double = 0.0, speed: Double = 0.0, elevation: Double = 0.0) {
        self.heartRate = heartRate
        self.distance = distance
        self.remainingSeconds = remainingSeconds
        self.isWorkoutRunning = isWorkoutRunning
        self.calories = calories
        self.isDistanceMetric = isDistanceMetric
        self.steps = steps
        self.speed = speed
        self.elevation = elevation
    }
}

public class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    public static let shared = WatchSessionManager()
    
    @Published public var workoutState: [String: Any] = [:]
    
    #if os(iOS)
    @Published public var heartRate: Double = 0.0
    @Published public var distance: Double = 0.0
    @Published public var isRunning: Bool = false
    @Published public var isWatchPaired: Bool = false
    @Published public var isWatchAppInstalled: Bool = false
    #endif
    
    public var isWatchConnected: Bool {
        #if targetEnvironment(simulator)
        return true
        #elseif os(iOS)
        return isWatchPaired
        #else
        return true
        #endif
    }
    
    private var session: WCSession?
    private var currentWorkoutSessionId: String = ""
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            #if os(iOS)
            self.isWatchPaired = session?.isPaired ?? false
            self.isWatchAppInstalled = session?.isWatchAppInstalled ?? false
            #endif
        }
    }

    // Kirim data workout — dipakai untuk sync metrics dari Watch ke iOS
    public func sendWorkoutUpdate(data: [String: Any]) {
        guard let session = session, session.activationState == .activated else { return }
        
        // Realtime via sendMessage kalau watch reachable
        if session.isReachable {
            session.sendMessage(data, replyHandler: nil) { _ in }
        }
        
        // applicationContext sebagai fallback (tapi tidak untuk "stopped" — supaya tidak cached)
        let status = data["status"] as? String ?? ""
        if status != "stopped" && status != "stop_request" {
            do {
                try session.updateApplicationContext(data)
            } catch {
                print("[WatchSessionManager] context error: \(error)")
            }
        }
    }
    
    // Stop signal — HANYA via sendMessage (tidak masuk applicationContext)
    public func sendStopSignal(sessionId: String) {
        guard let session = session, session.activationState == .activated else { return }
        let data: [String: Any] = ["status": "stopped", "sessionId": sessionId]
        if session.isReachable {
            session.sendMessage(data, replyHandler: nil, errorHandler: nil)
        }
    }
    
    public func beginNewWorkoutSession() -> String {
        let newId = UUID().uuidString
        self.currentWorkoutSessionId = newId
        return newId
    }
    
    public func getCurrentSessionId() -> String {
        return currentWorkoutSessionId
    }

    // MARK: - WCSessionDelegate
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[WatchSessionManager] WCSession activationState: \(activationState.rawValue)")
        #if os(iOS)
        DispatchQueue.main.async {
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            print("[WatchSessionManager] Watch status on activation: paired=\(session.isPaired), installed=\(session.isWatchAppInstalled)")
        }
        #endif
    }
    
    #if os(iOS)
    public func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            print("[WatchSessionManager] Watch state changed: paired=\(session.isPaired), installed=\(session.isWatchAppInstalled)")
        }
    }
    
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    // applicationContext: jangan proses "stopped" — bisa basi dari sesi lama
    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        let status = applicationContext["status"] as? String ?? ""
        if status != "stopped" && status != "stop_request" {
            handleReceivedData(applicationContext, source: "context")
        }
    }
    
    // sendMessage: proses semua termasuk "stopped" karena ini realtime
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleReceivedData(message, source: "message")
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleReceivedData(message, source: "message")
        replyHandler([:])
    }
    
    private func handleReceivedData(_ data: [String: Any], source: String) {
        DispatchQueue.main.async {
            self.workoutState = data
            
            #if os(iOS)
            // Decode WorkoutMetrics struct kalau ada
            if let rawMetrics = data["metrics"] as? Data,
               let metrics = try? JSONDecoder().decode(WorkoutMetrics.self, from: rawMetrics) {
                self.heartRate = metrics.heartRate
                if let dist = metrics.distance {
                    self.distance = Double(dist)
                }
                self.isRunning = metrics.isWorkoutRunning
                return
            }
            // Decode field by field
            if let hr = data["heartRate"] as? Double { self.heartRate = hr }
            if let dist = data["distance"] as? Double { self.distance = dist }
            let status = data["status"] as? String ?? ""
            if status == "stopped" { self.isRunning = false }
            else if status == "active" { self.isRunning = true }
            
            #else
            // Watch side: hanya proses stop — START sekarang hanya via startWatchApp/WatchAppDelegate
            let status = data["status"] as? String ?? ""
            if status == "stop_request" {
                let res = data["result"] as? String
                WatchWorkoutService.shared.endWorkout(notifyPhone: false, result: res)
            }
            if let hapticType = data["haptic"] as? String {
                #if os(watchOS)
                let type: WKHapticType
                switch hapticType {
                case "success": type = .success
                case "failure": type = .failure
                default: type = .notification
                }
                WKInterfaceDevice.current().play(type)
                #endif
            }
            // Simpan sessionId yang dikirim iOS supaya Watch tahu session aktif saat ini
            if let sessionId = data["sessionId"] as? String {
                WatchWorkoutService.shared.updateSessionId(sessionId)
            }
            #endif
        }
    }
}
