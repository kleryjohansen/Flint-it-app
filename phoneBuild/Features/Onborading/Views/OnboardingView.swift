import SwiftUI
import PhotosUI
import AuthenticationServices

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var isAnimatingLogo = false
    
    var body: some View {
        ZStack {
            // Background
            Color.flintBackground.ignoresSafeArea()
            
            // Glowing red radial light from bottom
            RadialGradient(
                gradient: Gradient(colors: [Color.flintRed.opacity(0.4), Color.clear]),
                center: .bottom,
                startRadius: 50,
                endRadius: 600
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    
                    // Animated Logo Header
                    VStack(spacing: 12) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 64))
                            .foregroundColor(Color.flintRed)
                            .shadow(color: Color.flintRed.opacity(0.6), radius: 15)
                            .scaleEffect(isAnimatingLogo ? 1.08 : 0.95)
                            .animation(
                                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                value: isAnimatingLogo
                            )
                            .onAppear {
                                isAnimatingLogo = true
                            }
                        
                        Text("FLINT")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .tracking(6)
                            .foregroundColor(.white)
                        
                        Text("Spark Your Fitness Connection")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 10)
                    
                    // Main Glassmorphic Card
                    VStack(spacing: 24) {
                        
                        // Avatar Photo Picker
                        VStack(spacing: 8) {
                            PhotosPicker(selection: $viewModel.selectedItem, matching: .images) {
                                ZStack(alignment: .bottomTrailing) {
                                    if let image = viewModel.profileImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 110, height: 110)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(Color.flintGlass)
                                            .frame(width: 110, height: 110)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .foregroundColor(.white.opacity(0.3))
                                                    .font(.system(size: 50))
                                            )
                                    }
                                    
                                    // Edit/Add Camera Indicator
                                    Circle()
                                        .fill(Color.flintRed)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white)
                                        )
                                        .shadow(radius: 4)
                                }
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 2))
                            }
                            .onChange(of: viewModel.selectedItem) { _ in
                                viewModel.processSelectedImage()
                            }
                            
                            Text("Set Profile Photo")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        // Username Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CHOOSE USERNAME")
                                .font(.caption2.bold())
                                .foregroundColor(.white.opacity(0.6))
                                .tracking(1)
                            
                            FlintTextField(placeholder: "e.g. fit_warrior", text: $viewModel.username, icon: "person.fill")
                        }
                        
                        // Apple Sign In Button Section
                        VStack(spacing: 16) {
                            Text("Sign in with Apple to create your profile securely without passwords.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 10)
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                    .frame(height: 50)
                            } else {
                                SignInWithAppleButton(.signUp) { request in
                                    request.requestedScopes = [.fullName, .email]
                                } onCompletion: { result in
                                    switch result {
                                    case .success(let authorization):
                                        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                            let userIdentifier = appleIDCredential.user
                                            let email = appleIDCredential.email
                                            
                                            // Format name
                                            var nameString: String? = nil
                                            if let name = appleIDCredential.fullName {
                                                let given = name.givenName ?? ""
                                                let family = name.familyName ?? ""
                                                nameString = "\(given) \(family)".trimmingCharacters(in: .whitespacesAndNewlines)
                                                if nameString?.isEmpty == true {
                                                    nameString = nil
                                                }
                                            }
                                            
                                            viewModel.handleAppleSignIn(
                                                userIdentifier: userIdentifier,
                                                fullName: nameString,
                                                email: email
                                            )
                                        }
                                    case .failure(let error):
                                        viewModel.errorMessage = "Sign In failed: \(error.localizedDescription)"
                                    }
                                }
                                .signInWithAppleButtonStyle(.white)
                                .frame(height: 50)
                                .cornerRadius(15)
                            }
                        }
                        
                        // Error message
                        if !viewModel.errorMessage.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                Text(viewModel.errorMessage)
                                    .font(.caption.bold())
                            }
                            .foregroundColor(Color.flintRed)
                            .transition(.opacity)
                        }
                    }
                    .padding(24)
                    .flintGlassCard()
                    .padding(.horizontal)
                    
                }
                .padding(.bottom, 50)
            }
        }
        // Redirect to ContentView on success
        .fullScreenCover(isPresented: $viewModel.isSuccess) {
            ContentView()
        }
    }
}

// MARK: - Custom Glass TextFields
struct FlintTextField: View {
    var placeholder: String
    @Binding var text: String
    var icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.flintRed)
                .font(.headline)
                .frame(width: 24)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
                .font(.body)
                .preferredColorScheme(.dark)
        }
        .padding(16)
        .background(Color.flintGlass)
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
