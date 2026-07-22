import SwiftUI
import AuthenticationServices
import PhotosUI
import Combine

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
            imageName: "onboardingBgdCycling"
        ),
        OnboardingPage(
            title: "Never Run Alone",
            description: "Find local runners for friendly matches. Track your distance and pace in real-time while creating a fresh and exciting experience with Nearfit.",
            imageName: "onboardingBgRunning"
        ),
        OnboardingPage(
            title: "Dive In Together",
            description: "Find swimming partners at your local pool. Challenge nearby swimmers to friendly matches and track every lap you swim with Nearfit.",
            imageName: "onboardingBgSwimming"
        )
    ]

    let timer = Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    let page = pages[index]
                    GeometryReader { geometry in
                        ZStack(alignment: .bottom) {
                            // Background Image
                            Image(page.imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                
                            // Gradient overlay for better text readability
                            Rectangle()
                                .fill(.thinMaterial)
                                .frame(height: 450)
                                .mask {
                                    LinearGradient(colors: [Color.black, Color.black, Color.black, Color.black.opacity(0)], startPoint: .bottom, endPoint: .top)
                                }
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.5), .black.opacity(0.9)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            
                            // Text Container
                            VStack(alignment: .leading, spacing: 12) {
                                Text(page.title)
                                    .font(.title .weight(.bold))
                                    .foregroundStyle(.primary)
                                    //.minimumScaleFactor(0.8)
                                
                                Text(page.description)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(4)
                                    // Fix: let wrapping work naturally without fixedSize horizontal forces
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 200)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .ignoresSafeArea()
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .padding(.top, 20)

                Spacer()
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.35))
                                .frame(width: index == currentPage ? 22 : 8, height: 8)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                            .frame(height: 50)
                    } else {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName]
                        } onCompletion: { result in
                            handleAppleResult(result)
                        }
                        .cornerRadius(72)
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
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
                    }

                    Text("By continuing, you agree to our \(Text("Terms of Service").foregroundColor(Color.flintRed)) and \(Text("Privacy Policy").foregroundColor(Color.flintRed)).")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.8)) {
                currentPage = (currentPage + 1) % pages.count
            }
        }
        .fullScreenCover(isPresented: $viewModel.isSignedIn) {
            ProfileSetupView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $viewModel.isSuccess) {
            ContentView()
        }
    }

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
            viewModel.errorMessage = "Sign In failed, Try Again"
        }
    }
}

// MARK: - Profile Setup Screen (shown after Apple Sign-In)

@MainActor
struct ProfileSetupView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @FocusState private var isNicknameFocused: Bool

    private var avatarImage: UIImage? { viewModel.profileImage }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            VStack(spacing: 8) {
                Text("One last step")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Set your name and photo so partners can recognise you.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
            .padding(.horizontal, 24)

            Spacer(minLength: 16)

            // MARK: Centered group (Avatar + Name) — together
            VStack(spacing: 24) {
                let snapshot = avatarImage
                PhotosPicker(selection: $viewModel.selectedItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let image = snapshot {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    Color.white.opacity(0.12)
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.white.opacity(0.6))
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

                        ZStack {
                            Circle().fill(Color.flintRed)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 32, height: 32)
                        .shadow(color: Color.flintRed.opacity(0.45), radius: 6)
                    }
                }
                .onChange(of: viewModel.selectedItem) { _, _ in
                    viewModel.processSelectedImage()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nickname")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Type here...", text: $viewModel.username)
                        .font(.body)
                        .foregroundStyle(.white)
                        .tint(.white)
                        .accentColor(.white)
                        .colorScheme(.dark)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .focused($isNicknameFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            isNicknameFocused = false
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.12))
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )

                    if !viewModel.errorMessage.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text(viewModel.errorMessage)
                                .font(.caption.bold())
                        }
                        .foregroundColor(Color.flintRed)
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)

            Spacer(minLength: 24)
        }
        .safeAreaInset(edge: .bottom) {
            // MARK: Action (bottom anchored above keyboard)
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                } else {
                    Button {
                        viewModel.completeProfile()
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FlintPrimaryButtonStyle())
                }

                Text("Your data stays private. We never share your information.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, isNicknameFocused ? 12 : 24)
        }
        .background {
            ZStack {
                Image("bgifhome")
                    .resizable()
                    .scaledToFill()

                Color.black.opacity(0.55)

                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black.opacity(0.65), .black.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 220)

                    Spacer()

                    LinearGradient(
                        colors: [.black.opacity(0), .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 220)
                }
                .allowsHitTesting(false)

                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.flintRed.opacity(0.18),
                        Color.black.opacity(0)
                    ]),
                    center: .center,
                    startRadius: 10,
                    endRadius: 320
                )
                .blendMode(.normal)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .fullScreenCover(isPresented: $viewModel.isSuccess) {
            ContentView()
        }
    }
}
// MARK: - Preview

#Preview {
    OnboardingView()
}

#Preview("Profile Setup") {
    ProfileSetupView(viewModel: OnboardingViewModel())
}
