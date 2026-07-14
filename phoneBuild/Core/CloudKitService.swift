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
}
