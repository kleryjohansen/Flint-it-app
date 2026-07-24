import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var profileImage: UIImage? = nil
    @State private var selectedProfileItem: PhotosPickerItem? = nil

    private var username: String {
        UserDefaults.standard.string(forKey: "savedUsername") ?? "Nearfit Athlete"
    }

    private var totalChallenges: Int {
        viewModel.pastWorkouts.count
    }

    private var wonChallenges: Int {
        viewModel.pastWorkouts.filter { $0.isVictory == true }.count
    }

    private var winRatio: Int {
        guard totalChallenges > 0 else { return 0 }
        return Int((Double(wonChallenges) / Double(totalChallenges)) * 100)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Strict dark background
            Color(red: 0.05, green: 0.04, blue: 0.04)
                .ignoresSafeArea()
            
            // Top ambient background gradient/image
            profileBackground
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    Spacer().frame(height: 120)
                    
                    // Main Profile Card
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color.black)
                        // Card Background
                        
                        VStack(spacing: 24) {
                            Spacer().frame(height: 50)
                            // Space for overlapping avatar
                            
                            // Name
                            Text(username)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            // Stats Grid
                            HStack(spacing: 16) {
                                StatCard(title: "Challenges", value: "\(totalChallenges)", icon: "figure.run", iconColor: Color("appPrimary"))
                                StatCard(title: "Wins", value: "\(wonChallenges)", icon: "trophy.fill", iconColor: Color("appPrimary"))
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 28)
                            
                        }
                        
                        // Overlapping Avatar with Edit Button
                        profileAvatar
                            .offset(y: -40)
                    }
                    .frame(height: 232)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    
                    VStack(spacing: 32){
                        
                        historySection
                            .padding(.top, 32)
                        
                        // Log Out CTA
                        Button(action: {
                            hasCompletedOnboarding = false
                        }) {
                            HStack(spacing: 4) {
                                Text("Log Out")
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(Color("appPrimary"))
                        }
                        .padding(.vertical, 40)
                        
                    }
                    .padding(.bottom, 120)
                    .background(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color.black)
                    )
                }
            }
            .ignoresSafeArea(edges: .all)
        }
        .onAppear {
            loadLocalProfileImage()
        }
        .onChange(of: selectedProfileItem) { _, newItem in
            Task {
                await loadSelectedProfileImage(from: newItem)
            }
        }
    }

    private var profileBackground: some View {
        Image("bgLobby")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .mask(
                LinearGradient(
                    gradient: Gradient(colors: [.black, .black.opacity(0.8), .clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .ignoresSafeArea()
            // Add a red tint to match the design's hue if the image doesn't natively have it
            .overlay(Color("appPrimary").opacity(0.15).ignoresSafeArea())
    }
        
    private var profileAvatar: some View {
        ZStack {
            // Avatar Background/Image
            if let uiImage = profileImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.2), Color(white: 0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    )
            }
            
            // Edit Pencil Button placed perfectly on the top-right curve edge
            PhotosPicker(selection: $selectedProfileItem, matching: .images) {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color("appPrimary")))
                    .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .offset(x: 35, y: -35)
        }
        .frame(width: 100, height: 100)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Challenge History")
                    .font(.headline.bold())
                    .foregroundColor(.white)

                Spacer()

                Button {
                    // See all action
                } label: {
                    HStack(spacing: 2) {
                        Text("See all")
                        Image(systemName: "chevron.right")
                            .font(.caption2.bold())
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            // Content
            if viewModel.pastWorkouts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("No recorded workouts yet")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Start a challenge with a nearby workout partner to record history.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.pastWorkouts) { workout in
                        HistoryRow(workout: workout)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func loadLocalProfileImage() {
        if let image = loadProfileImageFromDisk() {
            self.profileImage = image
        } else if let data = UserDefaults.standard.data(forKey: "savedProfileImageData"),
                  let image = UIImage(data: data) {
            // Fallback for older versions, then save it to disk for future
            self.profileImage = image
            saveProfileImageToDisk(image)
        }
    }

    @MainActor
    private func loadSelectedProfileImage(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }

        profileImage = image
        // Save to disk with compression instead of raw Data to UserDefaults
        saveProfileImageToDisk(image)
    }
}

// MARK: - Subcomponents

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Circle()
                    .fill(iconColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )

                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct HistoryRow: View {
    let workout: PastWorkout

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy • HH:mm"
        return formatter.string(from: workout.date)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Circle()
                .fill(Color(white: 0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: workout.type.iconName)
                        .font(.headline)
                        .foregroundColor(.white)
                )

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text("\(workout.type.rawValue) vs \(workout.partnerName ?? "Partner")")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            // Right-side indicator (matching the circle style from design)
            Circle()
                .stroke(Color.secondary, lineWidth: 1.5)
                .frame(width: 32, height: 32)
                .overlay(
                    Text("1") // Or swap for duration logic if you prefer dynamic text here
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                )
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(white: 0.12))
        )
    }
}

#Preview {
    ProfileView()
        .environmentObject(iOSWorkoutViewModel())
}
