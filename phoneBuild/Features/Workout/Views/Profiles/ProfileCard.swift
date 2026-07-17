//
//  ProfileHeader.swift
//  FlintItApp
//
//  Created by Elvira Oktaviani on 15/07/26.
//

import SwiftUI

struct ProfileCard: View {

    var body: some View {

        ZStack {

            RoundedRectangle(cornerRadius: 24)
                .fill(.white.opacity(0.08))
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 24) {

                // MARK: Header
                HStack(alignment: .top) {

                    VStack(alignment: .leading, spacing: 8) {

                        Text("Erling Antetokounmpo")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text("@erlingfitness")
                            .font(.subheadline)
                            .foregroundStyle(.orange)

                    }

                    Spacer()
                    
                    //foto profil
                    ZStack(alignment: .bottomTrailing) {

                        Image("profile")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 74, height: 74)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.orange, lineWidth: 2)
                            )

                        Button {

                        } label: {

                            Image(systemName: "pencil")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.orange)
                                .clipShape(Circle())

                        }

                    }

                }

                Divider()
                    .overlay(.white.opacity(0.15))

                // MARK: About

                VStack(alignment: .leading, spacing: 10) {

                    Label("About", systemImage: "person.text.rectangle")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("""
                    Love running and pushing my limits.
                    Always ready for the next challenge.
                    """)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineSpacing(4)

                }

            }
            .padding(24)

        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)

    }

}

#Preview {

    ZStack {

        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.22, green: 0.03, blue: 0.03)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        ProfileCard()
            .padding()

    }

}
