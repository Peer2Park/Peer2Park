//
//  MainTabView.swift
//  Peer2Park
//
//  Created by Trent S on 11/1/25.
//

import Foundation
import SwiftUI

struct MainTabView: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var locationManager: LocationManager
    @State private var showingCamera = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if showingCamera {
                    LiveVideoView(cameraManager: cameraManager)
                        .transition(.opacity)
                } else {
                    MapHomeView(locationManager: locationManager)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: showingCamera)

            VStack {
                HStack {
                    if showingCamera {
                        controlButton(systemName: "chevron.left") {
                            showingCamera = false
                        }
                        .accessibilityLabel("Back to map")
                    }

                    Spacer()

                    if !showingCamera {
                        controlButton(systemName: "camera.viewfinder") {
                            showingCamera = true
                        }
                        .accessibilityLabel("Show camera preview")
                    }
                }
                .padding()

                Spacer()
            }
        }
        .onAppear {
            if cameraManager.status == .authorized {
                cameraManager.startSession()
            } else {
                cameraManager.requestPermission()
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }

    // MARK: - Controls
    @ViewBuilder
    private func controlButton(systemName: String, action: @escaping () -> Void) -> some View {
        // Choose a high-contrast background color that adapts to the current color scheme.
        // In light mode: use a near-black translucent circle. In dark mode: use a near-white translucent circle.
        let bgColor: Color = (colorScheme == .dark) ? Color.white.opacity(0.92) : Color.black.opacity(0.82)
        let iconColor: Color = (colorScheme == .dark) ? Color.black : Color.white

        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2) // slightly larger for visibility
                .foregroundColor(iconColor)
                .padding(14)
                .background(
                    Circle()
                        .fill(bgColor)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                .accessibilityAddTraits(.isButton)
        }
    }
}
