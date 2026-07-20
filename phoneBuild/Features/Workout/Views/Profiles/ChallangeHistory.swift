//
//  ChallangeHistory.swift
//  FlintItApp
//
//  Created by Elvira Oktaviani on 15/07/26.
//

import Foundation

struct ChallengeHistory: Identifiable {

    let id = UUID()

    let icon: String
    let title: String
    let opponent: String
    let duration: String
    let date: String
    let isWin: Bool

}

extension ChallengeHistory {

    static let sampleData: [ChallengeHistory] = [

        ChallengeHistory(
            icon: "figure.run",
            title: "1 KM Sprint",
            opponent: "Andi",
            duration: "2m 56s",
            date: "Yesterday",
            isWin: true
        ),

        ChallengeHistory(
            icon: "bicycle",
            title: "5 KM Cycling",
            opponent: "Kevin",
            duration: "11m 42s",
            date: "2 days ago",
            isWin: false
        ),

        ChallengeHistory(
            icon: "dumbbell.fill",
            title: "Weightlifting",
            opponent: "Jason",
            duration: "8 reps",
            date: "Last week",
            isWin: true
        )

    ]

}
