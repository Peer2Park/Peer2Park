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

    var body: some View {
        TabView {

            MapHomeView(locationManager: locationManager)
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            LiveVideoView(cameraManager: cameraManager)
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
                .tabItem {
                    Label("Camera", systemImage: "camera.viewfinder")
                }

        }
    }
}
