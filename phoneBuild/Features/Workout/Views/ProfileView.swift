import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @State private var profileImage: UIImage? = nil

    private var username: String {
        UserDefaults.standard.string(forKey: "savedUsername") ?? "Nearfit Athlete"
    }

    private var email: String {
        UserDefaults.standard.string(forKey: "savedEmail") ?? "athlete@nearfit.com"
    }

    // Calculated statistics
    private var totalChallenges: Int {
        viewModel.pastWorkouts.count
    }

    private var averageHR: Int {
        guard !viewModel.pastWorkouts.isEmpty else { return 0 }
        let total = viewModel.pastWorkouts.reduce(0.0) { $0 + $1.avgHeartRate }
        return Int(total / Double(viewModel.pastWorkouts.count))
    }

    private var totalCalories: Double {
        viewModel.pastWorkouts.reduce(0.0) { $0 + ($1.calories ?? 0.0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Profile Header Info
            VStack(spacing: 12) {
                if let uiImage = profileImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color("appGlassBorder"), lineWidth: 2))
                } else {
                    Circle()
                        .fill(Color("appGlassWhite"))
                        .frame(width: 90, height: 90)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.largeTitle)
                                .foregroundColor(Color("appSecondaryLabel").opacity(0.8))
                        )
                        .overlay(Circle().stroke(Color("appGlassBorder"), lineWidth: 2))
                }

                VStack(spacing: 4) {
                    Text(username)
                        .font(.title3.bold())
                        .foregroundColor(Color("appLabel"))

                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(Color("appSecondaryLabel"))
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            // Statistics Grid (Glass Card style)
            HStack(spacing: 16) {
                StatItem(title: "Challenges", value: "\(totalChallenges)", icon: "trophy.fill", color: Color("appYellow"))
                StatItem(title: "Avg HR", value: averageHR > 0 ? "\(averageHR) BPM" : "---", icon: "heart.fill", color: Color("appRed"))
                StatItem(title: "Calories", value: String(format: "%.0f kcal", totalCalories), icon: "flame.fill", color: Color("appOrange"))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // History list section
            VStack(alignment: .leading, spacing: 12) {
                Text("Challenge History (\(totalChallenges))")
                    .font(.subheadline.bold())
                    .foregroundColor(Color("appSecondaryLabel"))
                    .tracking(0.5)
                    .padding(.horizontal, 24)

                if viewModel.pastWorkouts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(Color("appSecondaryLabel").opacity(0.6))

                        Text("No recorded workouts yet")
                            .font(.headline)
                            .foregroundColor(Color("appLabel"))

                        Text("Start a challenge with a nearby workout partner to record history.")
                            .font(.subheadline)
                            .foregroundColor(Color("appSecondaryLabel"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .flintGlassCard()
                    .padding(.horizontal, 24)
                } else {
                    List {
                        ForEach(viewModel.pastWorkouts) { workout in
                            HistoryRow(workout: workout)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 24, bottom: 6, trailing: 24))
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let workout = viewModel.pastWorkouts[index]
                                viewModel.forgetWorkout(workout)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.clear)
                }
            }

            Spacer()
        }
        .onAppear {
            loadLocalProfileImage()
        }
    }

    private func loadLocalProfileImage() {
        if let data = UserDefaults.standard.data(forKey: "savedProfileImageData"),
           let image = UIImage(data: data) {
            self.profileImage = image
        }
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
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.headline)
                .foregroundColor(Color("appLabel"))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color("appSecondaryLabel"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .flintGlassCard()
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
            // Icon matching workout sport type
            ZStack {
                Circle()
                    .fill(Color("appPrimary").opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: workout.type.iconName)
                    .font(.subheadline.bold())
                    .foregroundColor(Color("appPrimary"))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(workout.type.rawValue)
                        .font(.subheadline.bold())
                        .foregroundColor(Color("appLabel"))

                    if let partner = workout.partnerName {
                        Text("vs \(partner)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color("appSecondaryLabel"))
                            .lineLimit(1)
                    }
                }

                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(Color("appSecondaryLabel").opacity(0.8))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(durationString)
                    .font(.subheadline.bold())
                    .foregroundColor(Color("appLabel"))

                HStack(spacing: 8) {
                    if workout.avgHeartRate > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundColor(Color("appRed"))
                            Text("\(Int(workout.avgHeartRate))")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("appSecondaryLabel"))
                        }
                    }

                    if let cal = workout.calories, cal > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundColor(Color("appOrange"))
                            Text(String(format: "%.0f", cal))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("appSecondaryLabel"))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color("appGlassWhite"))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color("appGlassBorder"), lineWidth: 1)
        )
    }
}

#Preview {
    ProfileView()
        .environmentObject(iOSWorkoutViewModel())
}
