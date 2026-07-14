import Combine
import SwiftUI
import Foundation
import PhotosUI
import AuthenticationServices

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
            do {
                // Simpan ke CloudKit
                try await CloudKitService.shared.saveUserProfile(
                    username: finalUsername,
                    email: resolvedEmail,
                    profileImage: profileImage
                )
                
                // Simpan ke UserDefaults lokal
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                UserDefaults.standard.set(finalUsername, forKey: "savedUsername")
                UserDefaults.standard.set(resolvedEmail, forKey: "savedEmail")
                UserDefaults.standard.set(userIdentifier, forKey: "appleUserIdentifier")
                
                self.isLoading = false
                self.isSuccess = true
                
            } catch {
                self.isLoading = false
                self.errorMessage = "CloudKit Error: \(error.localizedDescription)"
            }
        }
    }
}
