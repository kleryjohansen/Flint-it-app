import SwiftUI
import UIKit
import MultipeerConnectivity

// MARK: - Badge Style
enum BadgeStyle {
    case solid
    case outline
}

struct RoomFormedView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @State private var isLoading = false

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
                                .padding(.top, !viewModel.partnerWatchConnected ? 0 : 24)
                            }

                            // SECTION 1: Who's in
                            let ownName = UserDefaults.standard.string(forKey: "savedUsername") ?? "You"
                            let totalCount: Int = {
                                if viewModel.isHost {
                                    return min(viewModel.roomParticipants.count + 1, 8)
                                } else {
                                    let others = viewModel.roomParticipants.filter {
                                        $0.id != viewModel.hostPeerID && $0.id != viewModel.multipeerManager?.peerID
                                    }
                                    return min(2 + others.count, 8)
                                }
                            }()

                            VStack(alignment: .leading, spacing: 14) {
                                Text("Who's in (\(totalCount))")
                                    .font(.subheadline)
                                    .foregroundColor(Color(white: 0.8))
                                    .padding(.horizontal, 4)
                                    .id(viewModel.rangeTick)  // re-evaluate on heartbeat tick

                                VStack(spacing: 12) {
                                    if viewModel.isHost {
                                        LobbyUserRow(
                                            name: ownName,
                                            isCurrentUser: true,
                                            badgeText: "Host",
                                            badgeColor: Color(white: 0.25),
                                            badgeTextColor: .white,
                                            badgeStyle: .solid,
                                            rangeStatus: .inRange,
                                            profileImage: loadProfileImageFromDisk()
                                        )
                                        ForEach(viewModel.roomParticipants.prefix(7)) { p in
                                            LobbyUserRow(
                                                name: p.displayName,
                                                isCurrentUser: false,
                                                badgeText: p.status == .connecting ? "Connecting…" : "Ready",
                                                badgeColor: Color("appRed"),
                                                badgeTextColor: Color("appRed"),
                                                badgeStyle: .outline,
                                                opacity: p.status == .connecting ? 0.5 : 1.0,
                                                rangeStatus: viewModel.rangeStatus(for: p.id),
                                                profileImage: viewModel.profileImages[p.id]
                                            )
                                        }
                                    } else {
                                        LobbyUserRow(
                                            name: viewModel.currentRoom?.partnerName
                                                ?? viewModel.hostPeerID?.displayName
                                                ?? "Host",
                                            isCurrentUser: false,
                                            badgeText: "Host",
                                            badgeColor: Color(white: 0.25),
                                            badgeTextColor: .white,
                                            badgeStyle: .solid,
                                            rangeStatus: viewModel.hostPeerID.map { viewModel.rangeStatus(for: $0) } ?? .unknown,
                                            profileImage: viewModel.hostPeerID.flatMap { viewModel.profileImages[$0] }
                                        )
                                        LobbyUserRow(
                                            name: ownName,
                                            isCurrentUser: true,
                                            badgeText: "Ready",
                                            badgeColor: Color("appRed"),
                                            badgeTextColor: Color("appRed"),
                                            badgeStyle: .outline,
                                            rangeStatus: .inRange,
                                            profileImage: loadProfileImageFromDisk()
                                        )
                                        ForEach(
                                            viewModel.roomParticipants.filter {
                                                $0.id != viewModel.hostPeerID && $0.id != viewModel.multipeerManager?.peerID
                                            }
                                        ) { p in
                                            LobbyUserRow(
                                                name: p.displayName,
                                                isCurrentUser: false,
                                                badgeText: p.status == .connecting ? "Connecting…" : "Ready",
                                                badgeColor: Color("appRed"),
                                                badgeTextColor: Color("appRed"),
                                                badgeStyle: .outline,
                                                opacity: p.status == .connecting ? 0.5 : 1.0,
                                                rangeStatus: viewModel.rangeStatus(for: p.id),
                                                profileImage: viewModel.profileImages[p.id]
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.top, (!viewModel.isHost) ? 12 : 24)

                            // SECTION 2: Invite more nearby (ONLY FOR HOST, jika belum lock)
                            if viewModel.isHost && !(viewModel.multipeerManager?.isRoomLocked ?? false) {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("Invite more nearby")
                                        .font(.subheadline)
                                        .foregroundColor(Color(white: 0.8))
                                        .padding(.horizontal, 4)

                                    let foundPeers = (viewModel.multipeerManager?.foundPeers ?? [])
                                        .filter { info in
                                            info.id != viewModel.multipeerManager?.peerID
                                                && !viewModel.roomParticipants.contains(where: { $0.id == info.id })
                                        }

                                    if foundPeers.isEmpty {
                                        Text("No one nearby yet. Open the app on another device to invite.")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(white: 0.6))
                                            .padding(.horizontal, 4)
                                    } else {
                                        VStack(spacing: 12) {
                                            ForEach(foundPeers) { info in
                                                LobbyInviteRow(
                                                    name: info.displayName,
                                                    onInvite: {
                                                        viewModel.multipeerManager?.invite(info.id)
                                                    }
                                                )
                                            }
                                        }
                                    }

                                    Text("*You can add up to 8 people. Discovery locks when you start a challenge.")
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
                            viewModel.skipConnectionAndGoToSetup()
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
    var opacity: Double = 1.0
    var rangeStatus: iOSWorkoutViewModel.RangeStatus? = nil
    var profileImage: UIImage? = nil

    var body: some View {
        HStack(spacing: 16) {
            avatarView
                .frame(width: 44, height: 44)
                .clipShape(Circle())

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

            if let rangeStatus {
                Circle()
                    .fill(rangeDotColor(rangeStatus))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .opacity(opacity)
    }
    
    private func rangeDotColor(_ status: iOSWorkoutViewModel.RangeStatus) -> Color {
        switch status {
        case .inRange: return .green
        case .far: return .yellow
        case .unknown: return .red
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let profileImage {
            Image(uiImage: profileImage)
                .resizable()
                .scaledToFill()
        } else {
            // Fallback: self = primary red, other = gray
            ZStack {
                Circle().fill(isCurrentUser ? Color("appPrimary") : Color(white: 0.4))
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(.white.opacity(isCurrentUser ? 0.9 : 0.7))
            }
        }
    }
}

struct LobbyInviteRow: View {
    let name: String
    var onInvite: () -> Void = {}

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

            Button(action: onInvite) {
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
