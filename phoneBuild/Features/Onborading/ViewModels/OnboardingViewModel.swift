import Combine
import SwiftUI
import Foundation
import PhotosUI
import AuthenticationServices
import CloudKit

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var username = ""
    
    // Untuk Foto Profil
    @Published var selectedItem: PhotosPickerItem? = nil
    @Published var profileImage: UIImage? = nil
    
    // State UI
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var isSuccess = false
    
    func processSelectedImage() {
        Task {
            if let data = try? await selectedItem?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                self.profileImage = uiImage
            }
        }
    }
    
    func handleAppleSignIn(userIdentifier: String, fullName: String?, email: String?) {
        // Validasi username
        let finalUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalUsername.isEmpty else {
            errorMessage = "Please choose a username before signing in."
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        let resolvedEmail = email ?? "user_\(userIdentifier.prefix(6))@apple.com"
        
        Task {
            // 1. Simpan ke UserDefaults lokal terlebih dahulu agar user bisa langsung menggunakan app
            UserDefaults.standard.set(finalUsername, forKey: "savedUsername")
            UserDefaults.standard.set(resolvedEmail, forKey: "savedEmail")
            UserDefaults.standard.set(userIdentifier, forKey: "appleUserIdentifier")
            if let image = profileImage, let pngData = image.pngData() {
                UserDefaults.standard.set(pngData, forKey: "savedProfileImageData")
            }
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            
            // 2. Coba simpan ke CloudKit di background
            do {
                try await CloudKitService.shared.saveUserProfile(
                    username: finalUsername,
                    email: resolvedEmail,
                    profileImage: profileImage
                )
                print("Berhasil sinkronisasi profil ke CloudKit!")
            } catch {
                // Log saja error CloudKit agar flow onboarding tidak terganggu (non-blocking)
                print("⚠️ CloudKit Sync Warning (Non-blocking): \(error.localizedDescription)")
            }
            
            self.isLoading = false
            self.isSuccess = true
        }
    }
    
    private func formatCloudKitError(_ error: Error) -> String {
        guard let ckError = error as? CKError else {
            return error.localizedDescription
        }
        
        switch ckError.code {
        case .notAuthenticated:
            return "Please sign in to iCloud on your device (Settings > iCloud) to save your profile."
        case .networkUnavailable, .networkFailure:
            return "Network connection issue. Please check your internet connection and try again."
        case .permissionFailure:
            return "iCloud permission denied. Please allow this app to access iCloud in your settings."
        case .quotaExceeded:
            return "Your iCloud storage is full. Please free up some space to save your profile."
        default:
            let description = error.localizedDescription
            if description.contains("Cannot create new type") || description.contains("production schema") {
                return "App setup error: The database schema needs to be deployed to Production in the Apple Developer Console."
            }
            return "CloudKit Error: \(description)"
        }
    }
}
