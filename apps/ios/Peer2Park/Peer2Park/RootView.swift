import SwiftUI
import AVFoundation
import CoreLocation

struct RootView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var locationManager = LocationManager()

    // Read the session-only flag from the environment
    @EnvironmentObject private var sessionManager: SessionManager

    private var permissionsApproved: Bool {
        let locationApproved =
            locationManager.status == .authorizedAlways ||
            locationManager.status == .authorizedWhenInUse
        let cameraApproved = cameraManager.status == .authorized
        return locationApproved && cameraApproved
    }

    var body: some View {
        //        Group {
        //            // If the user hasn't confirmed during this app session, show the captive login page.
        //            if !sessionManager.didConfirmLoginThisSession {
        //                // Present LoginView as the primary, captive page.
        //                LoginView()
        //                    // LoginView will read/write the session flag; environment object provided at app root
        //                    .environmentObject(sessionManager)
        //            } else {
        //                // Otherwise continue to the normal permissions/main flow.
        //                if permissionsApproved {
        //                    MainTabView(cameraManager: cameraManager, locationManager: locationManager)
        //                } else {
        //                    PermissionsView(cameraManager: cameraManager, locationManager: locationManager)
        //                }
        //            }
        //        }
        //        .animation(.easeInOut, value: sessionManager.didConfirmLoginThisSession)
        //        .transition(.opacity)
        if permissionsApproved {
            MainTabView(cameraManager: cameraManager, locationManager: locationManager)
        } else {
            PermissionsView(cameraManager: cameraManager, locationManager: locationManager)
        }
    }
}
