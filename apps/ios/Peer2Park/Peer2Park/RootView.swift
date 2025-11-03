import SwiftUI
import AVFoundation
import CoreLocation

struct RootView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var locationManager = LocationManager()

    private var permissionsApproved: Bool {
        let locationApproved =
            locationManager.status == .authorizedAlways ||
            locationManager.status == .authorizedWhenInUse
        let cameraApproved = cameraManager.status == .authorized
        return locationApproved && cameraApproved
    }

    var body: some View {
        Group {
            if permissionsApproved {
                MainTabView(cameraManager: cameraManager, locationManager: locationManager)
            } else {
                PermissionsView(cameraManager: cameraManager, locationManager: locationManager)
            }
        }
        .animation(.easeInOut, value: permissionsApproved)
        .transition(.opacity)
    }
}
