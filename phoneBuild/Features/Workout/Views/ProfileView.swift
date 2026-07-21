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
        ZStack {
            profileBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    profileHeader
                        .padding(.top, 70)

                    HStack(spacing: 10) {
                        StatItem(title: "Challenges", value: "\(totalChallenges)", icon: "trophy.fill", color: Color("appYellow"))
                        StatItem(title: "Won", value: "\(wonChallenges)", icon: "medal.fill", color: Color("appPrimary"))
                        StatItem(title: "Win Ratio", value: "\(winRatio)%", icon: "chart.line.uptrend.xyaxis", color: Color("appOrange"))
                    }
                    .padding(.horizontal, 22)

                    historySection
                        .padding(.bottom, 28)
                }
            }
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
        Image("bgifhome")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }

    private var profileHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color("appPrimary").opacity(0.18))
                    .frame(width: 108, height: 108)
                    .blur(radius: 18)

                if let uiImage = profileImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 2))
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color("appPrimary"), Color("appPrimaryDeep")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        )
                        .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 2))
                }

                PhotosPicker(selection: $selectedProfileItem, matching: .images) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color("appPrimary")))
                        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
                        .shadow(color: Color("appPrimaryDeep").opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .offset(x: 32, y: 32)
            }

            Text(username)
                .font(.title3.bold())
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 24)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Challenge History")
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                Button {
                } label: {
                    HStack(spacing: 3) {
                        Text("See all")
                        Image(systemName: "chevron.right")
                            .font(.caption2.bold())
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.86))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)

            if viewModel.pastWorkouts.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))

                    Text("No recorded workouts yet")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Start a challenge with a nearby workout partner to record history.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 42)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
                .glassEffect( in: .rect(cornerRadius: 24))
                .padding(.horizontal, 24)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.pastWorkouts) { workout in
                        HistoryRow(workout: workout)
                    }
                }
                .padding(.horizontal, 24)
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

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)

            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 104)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .glassEffect( in: .rect(cornerRadius: 24))
        .shadow(color: Color("appPrimaryDeep").opacity(0.22), radius: 18, x: 0, y: 10)
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
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color("appPrimary").opacity(0.2))
                    .frame(width: 42, height: 42)

                Image(systemName: workout.type.iconName)
                    .font(.subheadline.bold())
                    .foregroundColor(Color("appPrimary"))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(workout.type.rawValue)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)

                    if let partner = workout.partnerName {
                        Text("vs \(partner)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                }

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
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
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .glassEffect( in: .rect(cornerRadius: 24))
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
