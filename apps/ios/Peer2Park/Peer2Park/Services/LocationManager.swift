//
//  LocationManager.swift
//  Peer2Park
//
//  Created by Trent S on 10/6/25.
//

import Foundation
import SwiftUI
import CoreLocation

final class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    private let manager = CLLocationManager()
    @Published var status: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
        print("Authorization changed to: \(status.rawValue)")
    }
}
