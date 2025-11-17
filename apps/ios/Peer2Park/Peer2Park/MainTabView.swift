//
//  MainTabView.swift
//  Peer2Park
//
//  Created by Trent S on 11/1/25.
//

import SwiftUI
import Foundation

struct MainTabView: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var locationManager: LocationManager
    @State private var showingCamera = false

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
                }
                .padding()

                Spacer()
            }

            if !showingCamera {
                VStack {
                    Spacer()
                    controlButton(systemName: "camera.viewfinder") {
                        showingCamera = true
                    }
                    .accessibilityLabel("Show camera preview")
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 24)
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
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline)
                .foregroundColor(.white)
                .padding(12)
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}
