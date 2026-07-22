
//  SwiftUIView.swift
//  FlintItApp
//
//  Created by Elvira Oktaviani on 17/07/26.
//

import SwiftUI
import MultipeerConnectivity

struct MatchConfirmationView: View {
    @EnvironmentObject var viewModel: iOSWorkoutViewModel
    @State private var successScale: CGFloat = 0.2
    @State private var successRotation: Double = -160
    @State private var successOffset: CGFloat = 16
    @State private var radarScale: CGFloat = 0.45
    @State private var radarRotation: Double = -120
    @State private var radarOpacity: Double = 0.0
    @State private var hasScheduledRoomTransition = false

    private let successGreen = Color("appPrimary")
    private let successBlue = Color("appOrange")

    private var matchedName: String {
        viewModel.primaryPartnerName
        ?? viewModel.currentRoom?.partnerName
        ?? "Someone nearby"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                matchBackground

                VStack(spacing: 34) {
                    Spacer()

                    matchRadar

                    VStack(spacing: 10) {
                        Text("Match Found")
                            .font(.title.bold())
                            .foregroundColor(.white)

                        Text("Your workout buddy is ready. Choose a sport and challenge to get started.")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, 12)

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                playSuccessAnimation()
                scheduleRoomTransition()
            }
        }
    }

    private var matchBackground: some View {
        ZStack {
            Image("bgifhome")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .black.opacity(0.42),
                    Color("appPrimaryDeep").opacity(0.22),
                    .black.opacity(0.48)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var matchRadar: some View {
        ZStack {
            radarRings
                .scaleEffect(radarScale)
                .rotationEffect(.degrees(radarRotation))
                .opacity(radarOpacity)

            successDecoration

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [Color("appPrimary"), Color("appPrimaryDeep")]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 46
                        )
                    )
                    .frame(width: 92, height: 92)
                    .shadow(color: successGreen.opacity(0.62), radius: 18)

                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .scaleEffect(successScale)
            .rotationEffect(.degrees(successRotation))
            .offset(y: successOffset)
        }
        .frame(height: 300)
    }

    private var radarRings: some View {
        ZStack {
            Circle()
                .fill(successBlue.opacity(0.08))
                .frame(width: 286, height: 286)
                .blur(radius: 6)

            Circle()
                .stroke(successBlue.opacity(0.14), lineWidth: 2)
                .frame(width: 260, height: 260)
                .blur(radius: 2)

            Circle()
                .stroke(successGreen.opacity(0.16), lineWidth: 1)
                .frame(width: 210, height: 210)

            Circle()
                .fill(successGreen.opacity(0.055))
                .frame(width: 160, height: 160)
                .blur(radius: 1.5)

            Circle()
                .stroke(successGreen.opacity(0.16), lineWidth: 1)
                .frame(width: 150, height: 150)
                .blur(radius: 0.8)
        }
    }

    private var successDecoration: some View {
        ZStack {
            Image(systemName: "sparkle")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .offset(x: -82, y: -70)

            Circle()
                .fill(successGreen)
                .frame(width: 7, height: 7)
                .offset(x: 112, y: -92)

            Circle()
                .fill(Color.flintRed)
                .frame(width: 7, height: 7)
                .offset(x: -108, y: 96)

            Capsule()
                .fill(Color.yellow.opacity(0.9))
                .frame(width: 8, height: 28)
                .rotationEffect(.degrees(-38))
                .offset(x: -118, y: -28)

            Capsule()
                .fill(successGreen.opacity(0.9))
                .frame(width: 7, height: 24)
                .rotationEffect(.degrees(-35))
                .offset(x: 108, y: 54)

            Capsule()
                .fill(Color.yellow.opacity(0.95))
                .frame(width: 8, height: 34)
                .offset(x: 0, y: 116)
        }
    }

    private func scheduleRoomTransition() {
        guard !hasScheduledRoomTransition else { return }
        hasScheduledRoomTransition = true
        
        //2.2detik sblm dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            guard viewModel.appState == .foundPartner else { return }

            if viewModel.currentRoom == nil {
                viewModel.currentRoom = RoomSession(partnerName: matchedName, formedAt: Date())
            }

            withAnimation {
                viewModel.appState = .room
            }
        }
    }

    private func playSuccessAnimation() {
        successScale = 0.2
        successRotation = -160
        successOffset = 16
        radarScale = 0.45
        radarRotation = -120
        radarOpacity = 0.0

        withAnimation(.interpolatingSpring(stiffness: 95, damping: 10).delay(0.08)) {
            radarScale = 1.1
            radarRotation = 10
            radarOpacity = 1.0
        }

        withAnimation(.interpolatingSpring(stiffness: 120, damping: 15).delay(0.9)) {
            radarScale = 1.0
            radarRotation = 0
        }

        withAnimation(.interpolatingSpring(stiffness: 105, damping: 9).delay(0.2)) {
            successScale = 1.18
            successRotation = 12
            successOffset = -8
        }

        withAnimation(.interpolatingSpring(stiffness: 130, damping: 13).delay(1.02)) {
            successScale = 1.0
            successRotation = 0
            successOffset = 0
        }
    }
}

#Preview {
    MatchConfirmationView()
        .environmentObject(iOSWorkoutViewModel())
}
