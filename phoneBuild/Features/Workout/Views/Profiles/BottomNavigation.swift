//
//  BottomNavigation.swift
//  FlintItApp
//
//  Created by Elvira Oktaviani on 15/07/26.
//

import SwiftUI

struct BottomNavigation: View {

    @State private var selected = 2

    var body: some View {

        HStack {

            Spacer()

            navButton(
                icon: "house.fill",
                title: "Home",
                index: 0
            )

            Spacer()

            navButton(
                icon: "figure.run",
                title: "Challenge",
                index: 1
            )

            Spacer()

            navButton(
                icon: "person.fill",
                title: "Profile",
                index: 2
            )

            Spacer()

        }
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.horizontal, 24)
        .padding(.bottom, 20)

    }

    @ViewBuilder
    func navButton(
        icon: String,
        title: String,
        index: Int
    ) -> some View {

        Button {

            selected = index

        } label: {

            VStack(spacing: 6) {

                Image(systemName: icon)
                    .font(.title3)

                Text(title)
                    .font(.caption2)

            }
            .foregroundStyle(
                selected == index ? .orange : .gray
            )

        }

    }

}

#Preview {

    ZStack {

        Color.black
            .ignoresSafeArea()

        VStack {

            Spacer()

            BottomNavigation()

        }

    }

}
