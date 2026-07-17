import SwiftUI
import AuthenticationServices

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
}

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var currentPage = 0
    
    let pages = [
        OnboardingPage(
            title: "Ride Without Limits",
            description: "Discover cycling partners within your range. Challenge nearby friends and track every route you take. It's time to go further with Nearfit.",
            imageName: "cycling"
        ),
        OnboardingPage(
            title: "Never Run Alone",
            description: "Find local runners for friendly matches. Track your distance and pace in real-time while creating a fresh and exciting experience with Nearfit.",
            imageName: "run"
        ),
        OnboardingPage(
            title: "Dive In Together",
            description: "Find swimming partners at your local pool. Challenge nearby swimmers to friendly matches and track every lap you swim with Nearfit.",
            imageName: "swim"
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Swipeable background & content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        let page = pages[index]
                        ZStack(alignment: .bottomLeading) {
                            // Background Image
                            Image(page.imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                            
                            // Dark Overlay for text legibility
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .black.opacity(0.35),
                                    .black.opacity(0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            
                            // Text Content (Title & Description)
                            VStack(alignment: .leading, spacing: 16) {
                                Text(page.title)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                
                                Text(page.description)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 220) // Leave space so it doesn't overlap static controls
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()
                
                // Static Overlay (Title Logo, Apple Sign-in button, Terms, and Page indicators)
                VStack {
                    // Header logo Tolong Diganti
                    Text("NEARFIT")
                        .font(.system(size: 32, weight: .black))
                        .tracking(8)
                        .foregroundColor(.white)
                        .padding(.top, geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 20)
                    
                    Spacer()
                    
                    // Bottom Controls
                    VStack(spacing: 16) {
                        // Error message
                        if !viewModel.errorMessage.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                Text(viewModel.errorMessage)
                                    .font(.caption.bold())
                            }
                            .foregroundColor(Color.flintRed)
                            .padding(.horizontal)
                        }
                        
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
                                        
                                        var nameString = ""
                                        if let name = appleIDCredential.fullName {
                                            let given = name.givenName ?? ""
                                            let family = name.familyName ?? ""
                                            nameString = "\(given) \(family)".trimmingCharacters(in: .whitespacesAndNewlines)
                                        }
                                        
                                        // Auto-populate username so it passes validation
                                        if !nameString.isEmpty {
                                            viewModel.username = nameString.replacingOccurrences(of: " ", with: "_").lowercased()
                                        } else {
                                            viewModel.username = "nearfite_user"
                                        }
                                        
                                        viewModel.handleAppleSignIn(
                                            userIdentifier: userIdentifier,
                                            fullName: nameString.isEmpty ? nil : nameString,
                                            email: email
                                        )
                                    }
                                case .failure(let error):
                                    viewModel.errorMessage = "Sign In failed: \(error.localizedDescription)"
                                }
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 50)
                            .cornerRadius(25)
                            .padding(.horizontal, 24)
                        }
                        
                        // Terms text (matching mockup: "Terms of Service" and "Privacy Policy" highlighted in red)
                        Text("By continuing, you agree to our \(Text("Terms\nof Service").foregroundColor(Color.flintRed)) and \(Text("Privacy Policy").foregroundColor(Color.flintRed)).")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        // Page Indicators (Three dots)
                        HStack(spacing: 8) {
                            ForEach(0..<pages.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                    .animation(.spring(), value: currentPage)
                            }
                        }
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom : 20)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $viewModel.isSuccess) {
            ContentView()
        }
    }
}

#Preview {
    OnboardingView()
}

