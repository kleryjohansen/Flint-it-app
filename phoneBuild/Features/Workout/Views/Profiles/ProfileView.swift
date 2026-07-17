//
//  ProfileView.swift
//  FlintItApp
//
//  Created by Elvira Oktaviani on 15/07/26.
//

//ProfileCard.swift
//HistoryCard.swift
//BottomNavigation.swift
//GradientBackground.swift
//ChallengeHistory.swift

import SwiftUI

struct ProfileView: View {

    let history = ChallengeHistory.sampleData

    var body: some View {

        ZStack {

            // MARK: Background
            GradientBackground()

            VStack(spacing: 0) {

                // MARK: Navigation Bar
                HStack {

                    Button {
                        // Back Action
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(.white.opacity(0.08))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("Profile")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    Spacer()

                    // Balance the title
                    Color.clear
                        .frame(width: 42, height: 42)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                // MARK: Scroll Content
                ScrollView(showsIndicators: false) {

                    VStack(spacing: 20) {

                        // Profile Card
                        ProfileCard()

                        // History Header
                        HStack {

                            Label("History", systemImage: "clock")
                                .font(.headline)
                                .foregroundColor(.white)

                            Spacer()

                            Button {

                            } label: {

                                HStack(spacing: 4) {
                                    Text("See All")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.orange)
                            }

                        }

                        // History List
                        LazyVStack(spacing: 14) {

                            ForEach(history) { item in
                                HistoryCard(history: item)
                            }

                        }

                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 120)

                }

            }

        }
        .ignoresSafeArea()
        .navigationBarHidden(true)

    }
}

#Preview {
    ProfileView()
}
