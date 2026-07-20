//
//  HistoryCard.swift
//  FlintItApp
//
//  Created by Elvira Oktaviani on 15/07/26.
//

import SwiftUI

struct HistoryCard: View {

    let history: ChallengeHistory

    var body: some View {

        HStack(spacing: 16) {

            // MARK: Icon

            Image(systemName: history.icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.orange.opacity(0.2))
                .clipShape(Circle())

            // MARK: Detail

            VStack(alignment: .leading, spacing: 6) {

                Text(history.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(history.isWin ?
                     "Beat \(history.opponent)" :
                     "Lost to \(history.opponent)")
                    .font(.subheadline)
                    .foregroundStyle(history.isWin ? .green : .red)

                Label(history.duration,
                      systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.gray)

            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {

                Text(history.date)
                    .font(.caption)
                    .foregroundStyle(.gray)

                Text(history.isWin ? "Victory" : "Defeat")
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        history.isWin ?
                        Color.green.opacity(0.2) :
                        Color.red.opacity(0.2)
                    )
                    .foregroundStyle(
                        history.isWin ? .green : .red
                    )
                    .clipShape(Capsule())

            }

        }
        .padding()
        .background(.white.opacity(0.06))
        .clipShape(
            RoundedRectangle(cornerRadius: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.05))
        )

    }

}

#Preview {

    ZStack {

        Color.black
            .ignoresSafeArea()

        HistoryCard(
            history: ChallengeHistory.sampleData[0]
        )
        .padding()

    }

}
