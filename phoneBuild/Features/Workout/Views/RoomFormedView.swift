import SwiftUI

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
                    withAnimation {
                        viewModel.fullCleanup()
                    }
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
<<<<<<< ours

                    
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
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
>>>>>>> theirs
                    // SECTION 1: Who's in
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Who's in (2)")
                            .font(.subheadline).bold()
                            .foregroundColor(Color("appSecondaryLabel")) // P1-01
                            .tracking(1)
                            .padding(.horizontal, 4)

                        VStack(spacing: 12) {
<<<<<<< ours
                            // User row (Host) — P1-02: badge solid, warna border agar terlihat di light mode
                            LobbyUserRow(
                                name: UserDefaults.standard.string(forKey: "savedUsername") ?? "Kring Blesd",
                                isCurrentUser: true,
                                badgeText: "Host",
                                badgeColor: Color("appGlassBorder"),
                                badgeTextColor: Color("appSecondaryLabel"),
                                badgeStyle: .solid
                            )

                            // Partner row (Ready) — REDESIGN: outline style
                            LobbyUserRow(
                                name: viewModel.currentRoom?.partnerName ?? "Erling Antetokounmpo",
                                isCurrentUser: false,
                                badgeText: "Ready",
                                badgeColor: Color("appPrimary"),
                                badgeTextColor: Color("appPrimary"),
                                badgeStyle: .outline
                            )
                            if viewModel.isHost {
                                // Current User is Host, Partner is Guest
                                LobbyUserRow(
                                    name: UserDefaults.standard.string(forKey: "savedUsername") ?? "Kring Blesd",
                                    isCurrentUser: true,
                                    badgeText: "Host",
                                    badgeColor: Color("appGlassBorder"),
                                    badgeTextColor: Color("appSecondaryLabel"),
                                    badgeStyle: .solid
                                )
                                
                                LobbyUserRow(
                                    name: viewModel.currentRoom?.partnerName ?? "Erling Antetokounmpo",
                                    isCurrentUser: false,
                                    badgeText: "Ready",
                                    badgeColor: Color("appPrimary"),
                                    badgeTextColor: Color("appPrimary"),
                                    badgeStyle: .outline
                                )
                            } else {
                                // Partner is Host, Current User is Guest
                                LobbyUserRow(
                                    name: viewModel.currentRoom?.partnerName ?? "Erling Antetokounmpo",
                                    isCurrentUser: false,
                                    badgeText: "Host",
                                    badgeColor: Color("appGlassBorder"),
                                    badgeTextColor: Color("appSecondaryLabel"),
                                    badgeStyle: .solid
                                )
                                
                                LobbyUserRow(
                                    name: UserDefaults.standard.string(forKey: "savedUsername") ?? "Kring Blesd",
                                    isCurrentUser: true,
                                    badgeText: "Ready",
                                    badgeColor: Color("appPrimary"),
                                    badgeTextColor: Color("appPrimary"),
                                    badgeStyle: .outline
                                )
                            }
>>>>>>> theirs
                        }
                    }
                    .padding(.top, 20)

                    // SECTION 2: Invite more mates
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Invite more mates")
                            .font(.subheadline).bold()
                            .foregroundColor(Color("appSecondaryLabel")) // P1-01
                            .tracking(1)
                            .padding(.horizontal, 4)

                        VStack(spacing: 12) {
                            ForEach(nearbyMates, id: \.self) { name in
                                LobbyInviteRow(name: name)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

<<<<<<< ours
            // Bottom action button: "Continue to challenge" — P2-04: pakai PillButtonStyle
            Button(action: {
                withAnimation {
                    viewModel.appState = .workoutSetup
                }
            }) {
                Text("Continue to challenge")
                    .frame(maxWidth: .infinity)
            }
                .buttonStyle(PillButtonStyle())
            .buttonStyle(PillButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
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
>>>>>>> theirs
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
