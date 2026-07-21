import SwiftUI
import MultipeerConnectivity

// MARK: - Badge Style
enum BadgeStyle {
    case solid
    case outline
}

struct RoomFormedView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @State private var isLoading = false

    // Mock other nearby people to populate the invite list
    private let nearbyMates = [
        "Nathaniel John",
        "Jasper Komrade",
        "Christie Almanda"
    ]

    var body: some View {
        ZStack(alignment: .top) {
            // Force strict black background behind everything ignoring system theme
            Color.black.ignoresSafeArea()

            // Top background image
            Image("bgifrun")
                .resizable()
                .scaledToFill()
                .frame(width: UIScreen.main.bounds.width, height: 350)
                .clipped()
                .mask(LinearGradient(gradient: Gradient(colors: [.black, .black.opacity(0)]), startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Nav
                HStack {
                    Button(action: {
                        viewModel.activeAlert = .leaveConfirmation
                    }) {
                        Image(systemName: "xmark")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Title Area
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create the challenge")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                    Text("Discuss with your rivals to create the challenge")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 24)

                // Scrollable Content Area with Dark Card Background behind it
                ZStack(alignment: .top) {
                    // Dark backing card hugging the entire lists section
                    Color(white: 0.05)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .ignoresSafeArea(edges: .bottom)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {

                            let dist = viewModel.currentNearbyDistance
                            if dist > 0 {
                                HStack(spacing: 12) {
                                    Image(systemName: dist < 2.0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(dist < 2.0 ? Color.green : Color.orange)
                                    Text(dist < 2.0 ? "Rivals in Range (< 2m)" : "oops jangan jauh2 dari rival kamu")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(String(format: "%.1fm", dist))
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(14)
                                .background(dist < 2.0 ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(dist < 2.0 ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1))
                                .padding(.top, 24)
                            }

                            if !viewModel.partnerWatchConnected {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.applewatch")
                                        .foregroundColor(.orange)
                                    Text("\(viewModel.currentRoom?.partnerName ?? "Partner") is not connected to their Apple Watch.")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(14)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.35), lineWidth: 1))
                                .padding(.top, 8)
                            }

                            // GUEST BANNER: Waiting for Host
                            if !viewModel.isHost {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .stroke(Color("appRed").opacity(0.2), lineWidth: 3.5)

                                        Circle()
                                            .trim(from: 0, to: 0.75)
                                            .stroke(Color("appRed"), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                                            .rotationEffect(Angle(degrees: isLoading ? 360 : 0))
                                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isLoading)
                                            .onAppear { isLoading = true }
                                    }
                                    .frame(width: 24, height: 24)

                                    Text("Host picking a sport & challenge...")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color("appRed").opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color("appRed"), lineWidth: 1)
                                )
                                .padding(.top, dist > 0 || !viewModel.partnerWatchConnected ? 0 : 24)
                            }

                            // SECTION 1: Who's in
                            let connectedPeers = viewModel.multipeerManager?.session.connectedPeers ?? []
                            // +1 untuk diri sendiri yang tidak ada di connectedPeers
                            let totalCount = min(connectedPeers.count + 1, 8)
                            let ownName = UserDefaults.standard.string(forKey: "savedUsername") ?? "You"

                            VStack(alignment: .leading, spacing: 14) {
                                Text("Who's in (\(totalCount))")
                                    .font(.subheadline)
                                    .foregroundColor(Color(white: 0.8))
                                    .padding(.horizontal, 4)

                                VStack(spacing: 12) {
                                    // Row 1: Host selalu paling atas
                                    LobbyUserRow(
                                        name: viewModel.isHost ? ownName : (viewModel.currentRoom?.partnerName ?? "Host"),
                                        isCurrentUser: viewModel.isHost,
                                        badgeText: "Host",
                                        badgeColor: Color(white: 0.25),
                                        badgeTextColor: .white,
                                        badgeStyle: .solid
                                    )

                                    // Row 2: Jika Guest — tampilkan diri sendiri eksplisit setelah Host
                                    if !viewModel.isHost {
                                        LobbyUserRow(
                                            name: ownName,
                                            isCurrentUser: true,
                                            badgeText: "Ready",
                                            badgeColor: Color("appRed"),
                                            badgeTextColor: Color("appRed"),
                                            badgeStyle: .outline
                                        )
                                    }

                                    // Row 3+: Guest lain — hanya ditampilkan dari sisi Host
                                    // Dari sisi Guest, connectedPeers = Host (sudah di row 1), skip
                                    if viewModel.isHost {
                                        ForEach(connectedPeers.prefix(6), id: \.self) { peer in
                                            LobbyUserRow(
                                                name: peer.displayName,
                                                isCurrentUser: false,
                                                badgeText: "Ready",
                                                badgeColor: Color("appRed"),
                                                badgeTextColor: Color("appRed"),
                                                badgeStyle: .outline
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.top, (dist > 0 || !viewModel.isHost) ? 12 : 24)

                            // SECTION 2: Invite more nearby (ONLY FOR HOST)
                            if viewModel.isHost {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("Invite more nearby")
                                        .font(.subheadline)
                                        .foregroundColor(Color(white: 0.8))
                                        .padding(.horizontal, 4)

                                    VStack(spacing: 12) {
                                        ForEach(nearbyMates, id: \.self) { mate in
                                            LobbyInviteRow(name: mate)
                                        }
                                    }

                                    Text("*You can add up to 8 people.")
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(white: 0.6))
                                        .padding(.horizontal, 4)
                                        .padding(.top, 6)
                                }
                                .padding(.top, 12)
                            }

                            Spacer().frame(height: 120)
                        }
                        .padding(.horizontal, 24)
                    }
                }
            } // End main Vertical

            // Floating CTA Button at the absolute bottom
            VStack {
                Spacer()

                if viewModel.isHost {
                    Button(action: {
                        withAnimation {
                            viewModel.appState = .workoutSetup
                        }
                    }) {
                        Text("Create the challenge")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("appRed"))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .ignoresSafeArea(.keyboard)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Row Components
struct LobbyUserRow: View {
    let name: String
    let isCurrentUser: Bool
    let badgeText: String
    let badgeColor: Color
    let badgeTextColor: Color
    var badgeStyle: BadgeStyle = .solid

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 44, height: 44)
                .foregroundColor(Color("appPrimary"))
                .background(Circle().fill(Color("appOverlayDim")))

            Text(isCurrentUser ? "\(name) (You)" : name)
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Group {
                switch badgeStyle {
                case .solid:
                    Text(badgeText)
                        .font(.subheadline)
                        .foregroundColor(badgeTextColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(badgeColor))

                case .outline:
                    Text(badgeText)
                        .font(.subheadline)
                        .foregroundColor(badgeTextColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.clear))
                        .overlay(Capsule().stroke(badgeColor, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct LobbyInviteRow: View {
    let name: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 44, height: 44)
                .foregroundColor(Color(white: 0.4))
                .opacity(0.8)

            Text(name)
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Button(action: {}) {
                Text("Invite")
                    .font(.subheadline).bold()
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color("appRed"))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(white: 0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#Preview("Host View") {
    let mockHostVM = iOSWorkoutViewModel()
    mockHostVM.isHost = true
    return RoomFormedView()
        .environmentObject(mockHostVM)
}

#Preview("Guest View") {
    let mockGuestVM = iOSWorkoutViewModel()
    mockGuestVM.isHost = false
    return RoomFormedView()
        .environmentObject(mockGuestVM)
}
