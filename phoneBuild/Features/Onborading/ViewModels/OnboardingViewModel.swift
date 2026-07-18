import Combine
import SwiftUI
import Foundation
import PhotosUI
import AuthenticationServices
import CloudKit

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var username = ""

    // Profile photo
    @Published var selectedItem: PhotosPickerItem? = nil
    @Published var profileImage: UIImage? = nil

    // Auth state
    @Published var isLoading = false
    @Published var errorMessage = ""

    /// Set to true once Apple Sign-In succeeds → show ProfileSetupView
    @Published var isSignedIn = false

    /// Set to true once the user finishes setting their name → enter the app
    @Published var isSuccess = false

    // Stored during Apple sign-in so completeProfile() can use them
    private var pendingUserIdentifier = ""
    private var pendingFullName: String? = nil

    // MARK: - Step 1: Apple Sign-In (on Onboarding)

    func signInWithApple(userIdentifier: String, fullName: String?) {
        isLoading = true
        errorMessage = ""
        pendingUserIdentifier = userIdentifier
        pendingFullName = fullName

        // Pre-fill name field from Apple credential if we got one
        if let name = fullName, !name.isEmpty {
            username = name
        }

        // Save the Apple user ID immediately so we can recover the session
        UserDefaults.standard.set(userIdentifier, forKey: "appleUserIdentifier")

        isLoading = false
        isSignedIn = true
    }

    // MARK: - Step 2: Complete Profile (on ProfileSetupView)

    func completeProfile() {
        let finalName = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            errorMessage = "Please enter your name to continue."
            return
        }

        isLoading = true
        errorMessage = ""

        Task {
            // Save locally first so the app is immediately usable
            UserDefaults.standard.set(finalName, forKey: "savedUsername")
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

            if let image = profileImage, let pngData = image.pngData() {
                UserDefaults.standard.set(pngData, forKey: "savedProfileImageData")
            }

            // Sync to CloudKit in the background (non-blocking)
            do {
                try await CloudKitService.shared.saveUserProfile(
                    username: finalName,
                    email: "user_\(pendingUserIdentifier.prefix(6))@apple.com",
                    profileImage: profileImage
                )
                print("✅ Profile synced to CloudKit")
            } catch {
                print("⚠️ CloudKit sync (non-blocking): \(error.localizedDescription)")
            }

            self.isLoading = false
            self.isSuccess = true
        }
    }

    // MARK: - Photo

    func processSelectedImage() {
        Task {
            if let data = try? await selectedItem?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                self.profileImage = uiImage
            }
        }
    }
}
