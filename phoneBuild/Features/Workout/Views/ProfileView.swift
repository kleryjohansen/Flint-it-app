import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    // Bug 1 fix: @AppStorage reactive terhadap perubahan UserDefaults
    @AppStorage("savedUsername") private var username: String = "Nearfit Athlete"
    @State private var profileImage: UIImage? = nil
    @State private var selectedProfileItem: PhotosPickerItem? = nil

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
            Color(red: 0.05, green: 0.04, blue: 0.04)
                .ignoresSafeArea()

            profileBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 120)

                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color.black)

                        VStack(spacing: 22) {
                            Spacer()
                                .frame(height: 50)

                            Text(username)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .padding(.horizontal, 24)

                            statsGrid
                                .padding(.horizontal, 24)
                                .padding(.bottom, 28)
                        }

                        profileAvatar
                            .offset(y: -40)
                    }
                    .frame(minHeight: 306)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)

                    VStack(spacing: 32) {
                        historySection
                            .padding(.top, 32)
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
            // Bug 2 fix: baca dari Documents/profile.jpg
            profileImage = loadProfileImageFromDisk()
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
            .overlay(Color("appPrimary").opacity(0.15).ignoresSafeArea())
    }

    private var profileAvatar: some View {
        ZStack {
            if let uiImage = profileImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1.5))
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
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1.5))
            }

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

    private var statsGrid: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                StatCard(title: "Challenges", value: "\(totalChallenges)", icon: "figure.run", iconColor: Color("appPrimary"))
                StatCard(title: "Wins", value: "\(wonChallenges)", icon: "trophy.fill", iconColor: Color("appPrimary"))
            }

            StatCard(title: "Win Ratio", value: "\(winRatio)%", icon: "chart.line.uptrend.xyaxis", iconColor: Color("appOrange"))
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Challenge History")
                    .font(.headline.bold())
                    .foregroundColor(.white)

                Spacer()

                Button {
                } label: {
                    HStack(spacing: 3) {
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

    @MainActor
    private func loadSelectedProfileImage(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }

        // Bug 2 fix: simpan ke Documents/profile.jpg, bukan UserDefaults
        profileImage = image
        saveProfileImageToDisk(image)
    }
}

// MARK: - Row Components

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
                .lineLimit(1)
                .minimumScaleFactor(0.85)

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
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter.string(from: workout.date)
    }

    private var durationString: String {
        let minutes = Int(workout.duration) / 60
        let seconds = Int(workout.duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color(white: 0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: workout.type.iconName)
                        .font(.headline)
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(workout.type.rawValue)
                        .font(.headline.bold())
                        .foregroundColor(.white)

                    if let partner = workout.partnerName {
                        Text("vs \(partner)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(durationString)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if workout.avgHeartRate > 0 {
                        metricBadge(icon: "heart.fill", value: "\(Int(workout.avgHeartRate))", color: Color("appRed"))
                    }

                    if let cal = workout.calories, cal > 0 {
                        metricBadge(icon: "flame.fill", value: String(format: "%.0f", cal), color: Color("appOrange"))
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(white: 0.12))
        )
    }

    private func metricBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(value)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(iOSWorkoutViewModel())
}
