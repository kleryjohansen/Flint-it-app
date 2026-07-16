import Foundation
import CloudKit
import UIKit

class CloudKitService {
    static let shared = CloudKitService()
    
    // Kita simpan di Public Database agar user lain (calon partner workout) bisa melihat profil ini nanti
    private let publicDB = CKContainer.default().publicCloudDatabase
    
    private init() {}
    
    func saveUserProfile(username: String, email: String, profileImage: UIImage?) async throws {
        let record = CKRecord(recordType: "UserProfile")
        record["username"] = username as CKRecordValue
        record["email"] = email as CKRecordValue
        
        // Handle Foto Profil menjadi format CKAsset
        if let image = profileImage,
           let imageData = image.jpegData(compressionQuality: 0.8) {
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            do {
                try imageData.write(to: tempURL)
                let asset = CKAsset(fileURL: tempURL)
                record["profilePhoto"] = asset
            } catch {
                print("Gagal memproses foto: \(error)")
            }
        }
        
        // Simpan ke CloudKit
        do {
            try await publicDB.save(record)
            print("Berhasil menyimpan profil ke CloudKit!")
        } catch {
            print("CloudKit Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Online Searcher Matchmaking
    
    func registerSearchingStatus(username: String, isSearching: Bool) async {
        let recordID = CKRecord.ID(recordName: "Search_\(username)")
        
        let record = CKRecord(recordType: "OnlineSearcher", recordID: recordID)
        record["username"] = username as CKRecordValue
        record["isSearching"] = (isSearching ? 1 : 0) as CKRecordValue
        record["lastActive"] = Date() as CKRecordValue
        
        do {
            try await publicDB.save(record)
        } catch {
            // If already exists, we fetch and update or overwrite.
            do {
                let existing = try await publicDB.record(for: recordID)
                existing["isSearching"] = (isSearching ? 1 : 0) as CKRecordValue
                existing["lastActive"] = Date() as CKRecordValue
                try await publicDB.save(existing)
            } catch {}
        }
    }
    
    func fetchOnlineSearchers(excludeUsername: String) async -> [String] {
        let predicate = NSPredicate(format: "isSearching == 1 AND username != %@", excludeUsername)
        let query = CKQuery(recordType: "OnlineSearcher", predicate: predicate)
        
        do {
            let results = try await publicDB.records(matching: query)
            var searchers: [String] = []
            for (_, result) in results.matchResults {
                if let record = try? result.get(),
                   let username = record["username"] as? String,
                   let lastActive = record["lastActive"] as? Date,
                   Date().timeIntervalSince(lastActive) < 60 {
                    searchers.append(username)
                }
            }
            return searchers
        } catch {
            return []
        }
    }
    
    // MARK: - Internet Invitations
    
    func sendInternetInvite(from: String, to: String) async {
        let recordID = CKRecord.ID(recordName: "Invite_\(to)")
        let record = CKRecord(recordType: "InternetInvite", recordID: recordID)
        record["from"] = from as CKRecordValue
        record["to"] = to as CKRecordValue
        record["status"] = "pending" as CKRecordValue
        record["lastUpdate"] = Date() as CKRecordValue
        
        do {
            try await publicDB.save(record)
        } catch {
            do {
                let existing = try await publicDB.record(for: recordID)
                existing["from"] = from as CKRecordValue
                existing["status"] = "pending" as CKRecordValue
                existing["lastUpdate"] = Date() as CKRecordValue
                try await publicDB.save(existing)
            } catch {}
        }
    }
    
    func checkPendingInternetInvite(for toUsername: String) async -> (from: String, to: String)? {
        let recordID = CKRecord.ID(recordName: "Invite_\(toUsername)")
        do {
            let record = try await publicDB.record(for: recordID)
            if let status = record["status"] as? String, status == "pending",
               let from = record["from"] as? String,
               let to = record["to"] as? String,
               let lastUpdate = record["lastUpdate"] as? Date,
               Date().timeIntervalSince(lastUpdate) < 30 {
                return (from, to)
            }
        } catch {}
        return nil
    }
    
    func acceptInternetInvite(from: String) async {
        let ownUsername = UserDefaults.standard.string(forKey: "savedUsername") ?? ""
        let recordID = CKRecord.ID(recordName: "Invite_\(ownUsername)")
        do {
            let record = try await publicDB.record(for: recordID)
            record["status"] = "accepted" as CKRecordValue
            record["lastUpdate"] = Date() as CKRecordValue
            try await publicDB.save(record)
        } catch {}
    }
    
    func isInternetInviteAccepted(to toUsername: String) async -> Bool {
        let recordID = CKRecord.ID(recordName: "Invite_\(toUsername)")
        do {
            let record = try await publicDB.record(for: recordID)
            if let status = record["status"] as? String, status == "accepted" {
                return true
            }
        } catch {}
        return false
    }
    
    // MARK: - Workout Progress Synchronization
    
    func updateWorkoutProgress(roomID: String, isHost: Bool, progressValue: Double, progressRatio: Double, seconds: Int, isFinished: Bool, steps: Double = 0.0, speed: Double = 0.0, elevation: Double = 0.0) async {
        let recordID = CKRecord.ID(recordName: "WorkoutProgress_\(roomID)")
        
        do {
            let record: CKRecord
            do {
                record = try await publicDB.record(for: recordID)
            } catch {
                record = CKRecord(recordType: "WorkoutProgress", recordID: recordID)
            }
            
            if isHost {
                record["hostProgressValue"] = progressValue as CKRecordValue
                record["hostProgressRatio"] = progressRatio as CKRecordValue
                record["hostSeconds"] = seconds as CKRecordValue
                record["hostFinished"] = (isFinished ? 1 : 0) as CKRecordValue
                record["hostSteps"] = steps as CKRecordValue
                record["hostSpeed"] = speed as CKRecordValue
                record["hostElevation"] = elevation as CKRecordValue
            } else {
                record["guestProgressValue"] = progressValue as CKRecordValue
                record["guestProgressRatio"] = progressRatio as CKRecordValue
                record["guestSeconds"] = seconds as CKRecordValue
                record["guestFinished"] = (isFinished ? 1 : 0) as CKRecordValue
                record["guestSteps"] = steps as CKRecordValue
                record["guestSpeed"] = speed as CKRecordValue
                record["guestElevation"] = elevation as CKRecordValue
            }
            record["lastUpdate"] = Date() as CKRecordValue
            
            try await publicDB.save(record)
        } catch {
            print("[CloudKit] Error updating progress: \(error.localizedDescription)")
        }
    }
    
    func fetchWorkoutData(roomID: String) async throws -> CloudKitWorkoutData {
        let recordID = CKRecord.ID(recordName: "WorkoutProgress_\(roomID)")
        let record = try await publicDB.record(for: recordID)
        
        let hostVal = record["hostProgressValue"] as? Double ?? 0.0
        let hostRatio = record["hostProgressRatio"] as? Double ?? 0.0
        let hostSec = record["hostSeconds"] as? Int ?? 0
        let hostFin = (record["hostFinished"] as? Int ?? 0) == 1
        let hostSteps = record["hostSteps"] as? Double ?? 0.0
        let hostSpeed = record["hostSpeed"] as? Double ?? 0.0
        let hostElevation = record["hostElevation"] as? Double ?? 0.0
        
        let guestVal = record["guestProgressValue"] as? Double ?? 0.0
        let guestRatio = record["guestProgressRatio"] as? Double ?? 0.0
        let guestSec = record["guestSeconds"] as? Int ?? 0
        let guestFin = (record["guestFinished"] as? Int ?? 0) == 1
        let guestSteps = record["guestSteps"] as? Double ?? 0.0
        let guestSpeed = record["guestSpeed"] as? Double ?? 0.0
        let guestElevation = record["guestElevation"] as? Double ?? 0.0
        
        let updated = record["lastUpdate"] as? Date ?? Date()
        
        return CloudKitWorkoutData(
            hostProgressValue: hostVal,
            hostProgressRatio: hostRatio,
            hostSeconds: hostSec,
            hostFinished: hostFin,
            hostSteps: hostSteps,
            hostSpeed: hostSpeed,
            hostElevation: hostElevation,
            guestProgressValue: guestVal,
            guestProgressRatio: guestRatio,
            guestSeconds: guestSec,
            guestFinished: guestFin,
            guestSteps: guestSteps,
            guestSpeed: guestSpeed,
            guestElevation: guestElevation,
            lastUpdate: updated
        )
    }
}

public struct CloudKitWorkoutData {
    public let hostProgressValue: Double
    public let hostProgressRatio: Double
    public let hostSeconds: Int
    public let hostFinished: Bool
    public let hostSteps: Double
    public let hostSpeed: Double
    public let hostElevation: Double
    
    public let guestProgressValue: Double
    public let guestProgressRatio: Double
    public let guestSeconds: Int
    public let guestFinished: Bool
    public let guestSteps: Double
    public let guestSpeed: Double
    public let guestElevation: Double
    
    public let lastUpdate: Date
}
