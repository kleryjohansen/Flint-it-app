import SwiftUI
import AuthenticationServices
import PhotosUI

// MARK: - Data Model

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
}

// MARK: - Onboarding Carousel View

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

    var isLastPage: Bool { currentPage == pages.count - 1 }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Swipeable slide backgrounds
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        let page = pages[index]
                        ZStack(alignment: .bottomLeading) {
                            Image(page.imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()

                            LinearGradient(
                                colors: [.clear, .black.opacity(0.3), .black.opacity(0.88)],
                                startPoint: .top,
                                endPoint: .bottom
                            )

                            VStack(alignment: .leading, spacing: 12) {
                                Text(page.title)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)

                                Text(page.description)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 200)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()

                // Static overlay
                VStack {
                    Text("NEARFIT")
                        .font(.system(size: 32, weight: .black))
                        .tracking(8)
                        .foregroundColor(.white)
                        .padding(.top, geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 20)

                    Spacer()

                    VStack(spacing: 16) {
                        // Page indicator dots
                        HStack(spacing: 8) {
                            ForEach(0..<pages.count, id: \.self) { index in
                                Capsule()
                                    .fill(index == currentPage ? Color.white : Color.white.opacity(0.35))
                                    .frame(width: index == currentPage ? 22 : 8, height: 8)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                            }
                        }

                        // Non-last pages: Continue button
                        if !isLastPage {
                            Button {
                                withAnimation { currentPage += 1 }
                            } label: {
                                HStack(spacing: 8) {
                                    Text("Continue")
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .buttonStyle(FlintPrimaryButtonStyle())
                            .padding(.horizontal, 24)
                        } else {
                            // Last page: native Apple Sign In
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                    .frame(height: 54)
                            } else {
                                SignInWithAppleButton(.signIn) { request in
                                    request.requestedScopes = [.fullName]
                                } onCompletion: { result in
                                    handleAppleResult(result)
                                }
                                .signInWithAppleButtonStyle(.white)
                                .frame(height: 54)
                                .cornerRadius(27)
                                .padding(.horizontal, 24)
                            }

                            if !viewModel.errorMessage.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                    Text(viewModel.errorMessage)
                                        .font(.caption.bold())
                                }
                                .foregroundColor(Color.flintRed)
                                .padding(.horizontal, 24)
                            }
                        }

                        // Terms
                        Text("By continuing, you agree to our \(Text("Terms of Service").foregroundColor(Color.flintRed)) and \(Text("Privacy Policy").foregroundColor(Color.flintRed)).")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom + 8 : 28)
                }
            }
        }
        .preferredColorScheme(.dark)
        // Step 1 done → go to Profile Setup
        .fullScreenCover(isPresented: $viewModel.isSignedIn) {
            ProfileSetupView(viewModel: viewModel)
        }
        // Step 2 done → go to main app
        .fullScreenCover(isPresented: $viewModel.isSuccess) {
            ContentView()
        }
    }

    // MARK: - Apple Sign-In Handler

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

            var fullNameString = ""
            if let name = credential.fullName {
                let given = name.givenName ?? ""
                let family = name.familyName ?? ""
                fullNameString = "\(given) \(family)".trimmingCharacters(in: .whitespacesAndNewlines)
            }

            viewModel.signInWithApple(
                userIdentifier: credential.user,
                fullName: fullNameString.isEmpty ? nil : fullNameString
            )

        case .failure(let error):
            viewModel.errorMessage = "Sign In failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Profile Setup Screen (shown after Apple Sign-In)

struct ProfileSetupView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ZStack {
            // Black base, matches app dark screens
            Color.black.ignoresSafeArea()

            // Subtle red glow from bottom
            VStack {
                Spacer()
                RadialGradient(
                    gradient: Gradient(colors: [Color.flintRed.opacity(0.22), .clear]),
                    center: .center,
                    startRadius: 10,
                    endRadius: 280
                )
                .frame(height: 300)
            }
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {

                    // ── Header ──────────────────────────────────
                    VStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color.flintRed)
                            .shadow(color: Color.flintRed.opacity(0.55), radius: 14)

                        Text("One last step")
                            .font(.title2.bold())
                            .foregroundColor(Color("appLabel"))

                        Text("Set your name and photo so partners can recognise you.")
                            .font(.subheadline)
                            .foregroundColor(Color("appSecondaryLabel"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 60)

                    // ── Photo Picker ─────────────────────────────
                    PhotosPicker(selection: $viewModel.selectedItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if let image = viewModel.profileImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    ZStack {
                                        Color("appGlassWhite")
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 44))
                                            .foregroundColor(Color("appSecondaryLabel"))
                                    }
                                }
                            }
                            .frame(width: 110, height: 110)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(
                                    LinearGradient(
                                        colors: [Color.flintRed, Color.flintRed.opacity(0.4)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ), lineWidth: 2.5
                                )
                            )

                            // Camera badge
                            ZStack {
                                Circle().fill(Color.flintRed)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 32, height: 32)
                            .shadow(color: Color.flintRed.opacity(0.45), radius: 6)
                        }
                    }
                    .onChange(of: viewModel.selectedItem) { _, _ in
                        viewModel.processSelectedImage()
                    }

                    // ── Name Field ───────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        Label("YOUR NAME", systemImage: "person.text.rectangle")
                            .font(.caption.bold())
                            .foregroundColor(Color("appSecondaryLabel"))
                            .tracking(0.8)

                        TextField("e.g. Klery Johansen", text: $viewModel.username)
                            .font(.body)
                            .foregroundColor(Color("appLabel"))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color("appGlassWhite"))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color("appGlassBorder"), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)

                    // ── Error ────────────────────────────────────
                    if !viewModel.errorMessage.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.caption)
                            Text(viewModel.errorMessage).font(.caption.bold())
                        }
                        .foregroundColor(Color.flintRed)
                        .padding(.horizontal, 24)
                    }

                    // ── Continue Button ──────────────────────────
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                            .frame(height: 54)
                    } else {
                        Button {
                            viewModel.completeProfile()
                        } label: {
                            HStack(spacing: 8) {
                                Text("Continue")
                                Image(systemName: "arrow.right.circle.fill")
                            }
                        }
                        .buttonStyle(FlintPrimaryButtonStyle())
                        .padding(.horizontal, 24)
                    }

                    Text("Your data stays private. We never share your information.")
                        .font(.caption)
                        .foregroundColor(Color("appSecondaryLabel").opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Spacer(minLength: 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        // When profile saved → go to main app
        .fullScreenCover(isPresented: $viewModel.isSuccess) {
            ContentView()
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
