import SwiftUI
import MultipeerConnectivity

// MARK: - Badge Style

enum BadgeStyle {
    case solid
    case outline
}

struct RoomFormedView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel

    // Mock other nearby people to populate the invite list as seen in Screen 5
    private let nearbyMates = [
        "Nathaniel John",
        "Jasper Heinrich",
        "Olivia Amanda"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header (Lobby Title with Chevron Left back button to exit)
            HStack {
                Button(action: {
                    viewModel.activeAlert = .leaveConfirmation
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                        .padding(12) // P2-01: touch target ≥ 44pt
                        .background(Circle().fill(.ultraThinMaterial))
                }

                Spacer()

                Text("Lobby")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()
                Color.clear.frame(width: 44, height: 44) // P2-02: balance spacer yang robust
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {


                    
                    // Live Proximity Range Banner
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
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(dist < 2.0 ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.top, 16)
                        .transition(.slide.combined(with: .opacity))
                    }

                    // Partner Watch Warning Banner
                    if !viewModel.partnerWatchConnected {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.applewatch")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                            
                            Text("\(viewModel.currentRoom?.partnerName ?? "Partner") is not connected to their Apple Watch. They must pair a watch and open the Flint-it app.")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            Spacer()
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                        )
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    

                    // SECTION 1: Who's in (Dynamic Lobby - Supports up to 8 peers maximum)
                    let connectedPeers = viewModel.multipeerManager?.session.connectedPeers ?? []
                    let totalCount = min(connectedPeers.count + 1, 8)
                    
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Who's in (\(totalCount)/8)")
                            .font(.subheadline).bold()
                            .foregroundColor(Color("appSecondaryLabel"))
                            .tracking(1)
                            .padding(.horizontal, 4)

                        VStack(spacing: 12) {
                            // Host
                            LobbyUserRow(
                                name: viewModel.isHost ? (UserDefaults.standard.string(forKey: "savedUsername") ?? "Host") : (viewModel.currentRoom?.partnerName ?? "Host"),
                                isCurrentUser: viewModel.isHost,
                                badgeText: "Host",
                                badgeColor: Color("appGlassBorder"),
                                badgeTextColor: Color("appSecondaryLabel"),
                                badgeStyle: .solid
                            )
                            
                            // Connected Guest/Rival peers (max 7 guests + 1 host = 8 total)
                            ForEach(connectedPeers.prefix(7), id: \.self) { peer in
                                let isMe = peer == viewModel.multipeerManager?.peerID
                                if !isMe {
                                    LobbyUserRow(
                                        name: peer.displayName,
                                        isCurrentUser: false,
                                        badgeText: "Rival",
                                        badgeColor: Color("appPrimary"),
                                        badgeTextColor: Color("appPrimary"),
                                        badgeStyle: .outline
                                    )
                                }
                            }
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            // Bottom action button: Host vs Guest action control
            if viewModel.isHost {
                Button(action: {
                    withAnimation {
                        viewModel.appState = .workoutSetup
                    }
                }) {
                    Text("Continue to challenge")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(PillButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            } else {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.primary)
                    Text("Waiting for Host")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color("appGlassWhite"))
                .cornerRadius(24)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }

        }
        .flintVibrantBackground()
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
                .overlay(Circle().stroke(Color("appGlassBorder"), lineWidth: 1))

            Text(isCurrentUser ? "\(name) (You)" : name)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            // Badge: solid atau outline tergantung badgeStyle
            Group {
                switch badgeStyle {
                case .solid:
                    Text(badgeText)
                        .font(.caption).bold()
                        .foregroundColor(badgeTextColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(badgeColor))

                case .outline:
                    Text(badgeText)
                        .font(.caption).bold()
                        .foregroundColor(badgeTextColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(badgeColor.opacity(0.1))
                        )
                        .overlay(
                            Capsule().stroke(badgeColor, lineWidth: 1.5)
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color("appGlassWhite"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)) // P2-03
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous) // P2-03
                .stroke(Color("appGlassBorder"), lineWidth: 1)
        )
    }
}

struct LobbyInviteRow: View {
    let name: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 44, height: 44)
                .foregroundColor(Color("appGray"))
                .opacity(0.6)

            Text(name)
                .font(.headline)
                .foregroundColor(.primary) // P1-03: adaptif, kontras baik

            Spacer()

            // REDESIGN: Tombol Invite — outline style konsisten dengan badge Ready
            Button(action: {}) {
                Text("Invite")
                    .font(.caption).bold()
                    .foregroundColor(Color("appPrimary"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color("appPrimary").opacity(0.08))
                    )
                    .overlay(
                        Capsule().stroke(Color("appPrimary"), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color("appGlassWhite"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)) // P2-03
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous) // P2-03
                .stroke(Color("appGlassBorder"), lineWidth: 1)
        )
    }
}

#Preview {
    RoomFormedView()
        .environmentObject(iOSWorkoutViewModel())
}
