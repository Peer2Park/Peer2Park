//
//  MapHomeView.swift
//  Peer2Park
//
//  Created by Trent S on 11/1/25.
//

import Foundation
import SwiftUI
import MapKit

struct MapHomeView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var cameraPosition: MapCameraPosition = .automatic

    var userCoordinate: CLLocationCoordinate2D? {
        locationManager.userLocation
    }

    var body: some View {
        ZStack {
            if let userCoord = userCoordinate {
                Map(position: $cameraPosition) {
                    Marker("You", systemImage: "location.fill", coordinate: userCoord)
                        .tint(.blue)
                }
                .edgesIgnoringSafeArea(.all)
                .onReceive(locationManager.$userLocation.compactMap { $0 }) { newCoord in
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: newCoord,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                }

            } else {
                ProgressView("Locating...")
                    .foregroundColor(.gray)
            }
        }
    }
}
