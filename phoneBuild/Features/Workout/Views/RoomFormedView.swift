import SwiftUI

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
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                
                Spacer()
                
                Text("Lobby")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                Spacer().frame(width: 44) // Balance back button
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
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
                    
                    // SECTION 1: Who's in
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Who's in (2)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            if viewModel.isHost {
                                // Current User is Host, Partner is Guest
                                LobbyUserRow(
                                    name: UserDefaults.standard.string(forKey: "savedUsername") ?? "Kring Blesd",
                                    isCurrentUser: true,
                                    badgeText: "Host",
                                    badgeColor: Color.white.opacity(0.12),
                                    badgeTextColor: .white
                                )
                                
                                LobbyUserRow(
                                    name: viewModel.currentRoom?.partnerName ?? "Erling Antetokounmpo",
                                    isCurrentUser: false,
                                    badgeText: "Guest",
                                    badgeColor: Color.flintRed,
                                    badgeTextColor: .white
                                )
                            } else {
                                // Partner is Host, Current User is Guest
                                LobbyUserRow(
                                    name: viewModel.currentRoom?.partnerName ?? "Erling Antetokounmpo",
                                    isCurrentUser: false,
                                    badgeText: "Host",
                                    badgeColor: Color.white.opacity(0.12),
                                    badgeTextColor: .white
                                )
                                
                                LobbyUserRow(
                                    name: UserDefaults.standard.string(forKey: "savedUsername") ?? "Kring Blesd",
                                    isCurrentUser: true,
                                    badgeText: "Guest",
                                    badgeColor: Color.flintRed,
                                    badgeTextColor: .white
                                )
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    // SECTION 2: Invite more mates
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Invite more mates")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
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

            // Bottom action button: Host vs Guest action control
            if viewModel.isHost {
                Button(action: {
                    withAnimation {
                        viewModel.appState = .workoutSetup
                    }
                }) {
                    Text("Continue to challenge")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.flintRed)
                        .clipShape(Capsule())
                        .shadow(color: Color.flintRed.opacity(0.35), radius: 12, y: 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            } else {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Waiting for Host")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.04))
                .cornerRadius(24)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .flintVibrantBackground()
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Row Components

struct LobbyUserRow: View {
    let name: String
    let isCurrentUser: Bool
    let badgeText: String
    let badgeColor: Color
    let badgeTextColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 44, height: 44)
                .foregroundColor(.orange)
                .background(Circle().fill(Color.black.opacity(0.2)))
                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
            
            Text(isCurrentUser ? "\(name) (You)" : name)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(badgeText)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(badgeTextColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(badgeColor)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
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
                .foregroundColor(.gray)
                .opacity(0.6)
            
            Text(name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Button(action: {}) {
                Text("invite")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.flintRed)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.02))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.02), lineWidth: 1)
        )
    }
}

#Preview {
    RoomFormedView()
        .environmentObject(iOSWorkoutViewModel())
}
