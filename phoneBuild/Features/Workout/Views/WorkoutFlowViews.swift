import SwiftUI
import MultipeerConnectivity

struct DiscoveryView: View {
    @ObservedObject var viewModel: iOSWorkoutViewModel
    @State private var selection = 0
    
    var body: some View {
        VStack(spacing: 30) {
            Picker("Mode", selection: $selection) {
                Text("Find Partner").tag(0)
                Text("My Profile").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top, 40)
            
            if selection == 0 {
                VStack {
                    Text("People Nearby")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    if viewModel.connectivityService.discoveredPeers.isEmpty {
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            Text("Scanning...")
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                                ForEach(viewModel.connectivityService.discoveredPeers, id: \.self) { peer in
                                    VStack(spacing: 12) {
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .frame(width: 60, height: 60)
                                            .foregroundColor(.orange)
                                        Text(peer.displayName)
                                            .font(.headline)
                                            .foregroundColor(.black)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(Color.white)
                                    .cornerRadius(20)
                                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                                    .contextMenu {
                                        Button(action: {
                                            viewModel.invite(peer: peer)
                                        }) {
                                            Label("Invite to Workout", systemImage: "paperplane.fill")
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            } else {
                ProfileHistoryView(viewModel: viewModel)
            }
        }
        .vibrantBackground()
    }
}

struct WorkoutSelectionView: View {
    @ObservedObject var viewModel: iOSWorkoutViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Select Workout")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
                .padding(.top, 40)
            
            VStack(spacing: 20) {
                ForEach(WorkoutType.allCases) { type in
                    Button(action: {
                        viewModel.selectedWorkoutType = type
                    }) {
                        HStack {
                            Text(type.rawValue)
                                .font(.headline)
                                .foregroundColor(viewModel.selectedWorkoutType == type ? .white : .black)
                            Spacer()
                            if viewModel.selectedWorkoutType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(viewModel.selectedWorkoutType == type ? Color.orange : Color.white)
                        .cornerRadius(15)
                    }
                }
                
                Toggle("Competition Mode", isOn: $viewModel.isChallengeMode)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .foregroundColor(.black)
                    .padding(.top, 20)
            }
            .glassCard()
            .padding(.horizontal)
            
            Spacer()
            
            Button("Next") {
                viewModel.proceedToConnected()
            }
            .buttonStyle(PillButtonStyle())
            .padding(.bottom, 40)
        }
        .vibrantBackground()
    }
}

struct ConnectedView: View {
    @ObservedObject var viewModel: iOSWorkoutViewModel
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Image(systemName: "link.circle.fill")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.white)
            
            Text("Partner Connected!")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            
            Text("Ready for \(viewModel.selectedWorkoutType.rawValue)")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            if viewModel.isChallengeMode {
                Text("Competition Mode Enabled")
                    .font(.headline)
                    .foregroundColor(.yellow)
                    .padding(.top, -20)
            }
            
            Spacer()
            
            Button("Start Workout") {
                viewModel.startWorkout()
            }
            .buttonStyle(PillButtonStyle(color: .white))
            .foregroundColor(.orange)
            .padding(.bottom, 40)
        }
        .vibrantBackground()
    }
}

struct ActiveWorkoutDashboard: View {
    @ObservedObject var viewModel: iOSWorkoutViewModel
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Active Workout")
                .font(.title2.bold())
                .foregroundColor(.white.opacity(0.9))
                .padding(.top, 40)
            
            VStack {
                Text(viewModel.countdownText)
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .monospacedDigit()
                
                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 40))
                        Text("\(Int(viewModel.heartRate))")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                        Text("BPM")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 40))
                        
                        if let distance = viewModel.distanceToPeer {
                            Text(String(format: "%.1f", distance))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                        } else {
                            Text("--")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                        }
                        
                        Text("Meters")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
            }
            .padding(.vertical, 40)
            .glassCard()
            .padding(.horizontal)
            
            Spacer()
            
            Button("End Workout") {
                viewModel.stopWorkoutFromButton()
            }
            .buttonStyle(PillButtonStyle(color: .white))
            .foregroundColor(.red)
            .padding(.bottom, 40)
        }
        .vibrantBackground()
    }
}

struct ProfileHistoryView: View {
    @ObservedObject var viewModel: iOSWorkoutViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.orange)
                Text("My Profile")
                    .font(.title.bold())
                    .foregroundColor(.black)
                Text("Synced with HealthKit")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .glassCard()
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 15) {
                Text("Recent History")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(viewModel.pastWorkouts) { workout in
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(workout.type.rawValue)
                                        .font(.headline)
                                        .foregroundColor(.black)
                                    Text("\(Int(workout.duration / 60)) min • \(Int(workout.avgHeartRate)) avg BPM")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(workout.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(15)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                            .contextMenu {
                                Button(action: {
                                    viewModel.compareWorkout(workout)
                                }) {
                                    Label("Compare Result", systemImage: "chart.bar.fill")
                                }
                                Button(role: .destructive, action: {
                                    viewModel.forgetWorkout(workout)
                                }) {
                                    Label("Forget", systemImage: "trash.fill")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct ResultsView: View {
    @ObservedObject var viewModel: iOSWorkoutViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Summary")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
                .padding(.top, 40)
            
            VStack(spacing: 25) {
                SummaryRow(icon: "timer", title: "Total Time", value: viewModel.countdownText)
                SummaryRow(icon: "heart.fill", title: "Final Heart Rate", value: "\(Int(viewModel.heartRate)) BPM")
            }
            .glassCard()
            .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 15) {
                Button("Add Friend") {
                    viewModel.addFriend()
                }
                .buttonStyle(PillButtonStyle(color: .white))
                .foregroundColor(.blue)
                
                Button("Rematch") {
                    viewModel.rematch()
                }
                .buttonStyle(PillButtonStyle())
            }
            .padding(.bottom, 40)
        }
        .vibrantBackground()
    }
}

struct SummaryRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
                .foregroundColor(.orange)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.black)
                .bold()
        }
        .font(.title3)
    }
}
