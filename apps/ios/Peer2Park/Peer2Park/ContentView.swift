// ContentView.swift
// This is the main entry point for the Peer2Park iOS app's UI.
// It manages permissions, displays the welcome screen, and navigates to live video and map views.
// Comments throughout explain Swift concepts and app logic for beginners.
// # MARK: - Imports
import SwiftUI // SwiftUI is Apple's framework for building user interfaces.
import Peer2ParkNetworking // Custom networking code for API calls.
import AVFoundation // Used for camera permissions and video capture.

struct ContentView: View {
    // MARK: - State Properties
    // 'status' tracks the API health check result.
    @StateObject private var networkService = NetworkService()

    // LocationManager and CameraManager are custom classes in Services/ that handle permissions.
    @StateObject private var locationManager = LocationManager()
    @StateObject private var cameraManager = CameraManager()
    
    // Controls whether the live video view is shown.
    @State private var showLiveVideo = false
    
    // Computed property to check if API testing is enabled from Info.plist.
    private var APITestEnabled: Bool {
        if let value = Bundle.main.infoDictionary?["API_TEST_ENABLED"] as? String {
            return value == "YES"
        }
        return false
    }
    
    
    
    // MARK: - Main View Body
    // The body property describes the UI layout using SwiftUI views.
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ZStack {

                    Color(.white)
                        .ignoresSafeArea() // Ensures background color covers the whole screen.
                    VStack(spacing: 12) {
                        // App Icon Image
                        // #MARK: Welcome Image and Text
                        Image("peer2park")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 180, height: 180)
                            .cornerRadius(20)
                        // Welcome text
                        Text("Welcome to Parking Reimagined")
                            .font(Font.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        // Show API info if testing is enabled
                        if APITestEnabled {
                            VStack(spacing: 4) {
                                Text("Env: \(AppConfig.environment.rawValue)")
                                Text("Base: \(AppConfig.apiBaseURL.absoluteString)").font(.footnote)
                                Text("Health: \(networkService.healthStatus)")
                            }
                            .task {
                                await networkService.pingHealth()
                            }
                        }

                        //# MARK: Location Permission
                        // Location permission status and button
                        Text("Location Status: \(locationStatusText)")
                            .font(.caption)
                        if locationManager.status == .denied {
                            // If location is denied, show instructions and button to open settings.
                            VStack(spacing: 8) {
                                Text("Location access was denied. To enable:")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Button("Open Settings") {
                                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(settingsUrl)
                                    }
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        else if locationManager.status == .authorizedAlways {
                            // Location is fully authorized; no action needed.
                        }
                        else {
                            // If not authorized, show button to request permission.
                            Button("Request Location Permission") {
                                locationManager.requestPermission()
                            }
                        }
                        // # MARK: Camera Permission
                        // Camera permission status and button
                        Text("Camera Status: \(cameraStatusText)")
                            .font(.caption)
                        if cameraManager.status == .denied {
                            // If camera is denied, show instructions and button to open settings.
                            VStack(spacing: 8) {
                                Text("Camera access was denied. To enable:")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Button("Open Settings") {
                                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(settingsUrl)
                                    }
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        else if cameraManager.status == .authorized {
                            // Camera is authorized; no action needed.
                        }
                        else {
                            // If not authorized, show button to request permission.
                            Button("Request Camera Permission") {
                                cameraManager.requestPermission()
                            }
                        }
                        // # MARK: Main Actions
                        // If all permissions are approved, show main actions.
                        if permissionsApproved {
                            Text("All permissions granted! Ready to go.")
                                .foregroundStyle(Color.green)
                            Button("Show Live Video") {
                                showLiveVideo = true
                            }
                            .foregroundStyle(Color.blue)
                            .padding(.top)
                            // Navigation link to map view
                            NavigationLink(destination: MapHomeView(locationManager: locationManager)) {
                                Text("See Yourself on the Map")
                                    .font(.headline)
                                    .padding()
                                    .background(Color.blue.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    }.padding()
                }
            }
            // Navigation to live video view when showLiveVideo is true.
            .navigationDestination(isPresented: $showLiveVideo) {
                LiveVideoView(cameraManager: cameraManager).onAppear {
                    // Ensure camera permission is requested when view appears.
                    cameraManager.requestPermission()
                }
                
            }
        }
    }

    
    // MARK: - Helper Properties
    // Returns a user-friendly string for location permission status.
    private var locationStatusText: String {
        switch locationManager.status {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .authorizedWhenInUse: return "When In Use"
        case .authorizedAlways: return "Always"
        @unknown default: return "Unknown"
        }
    }
    // Returns a user-friendly string for camera permission status.
    private var cameraStatusText: String {
        switch cameraManager.status {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .restricted: return "Restricted"
        @unknown default: return "Unknown"
        }
    }
    // Returns true if both location and camera permissions are granted.
    private var permissionsApproved: Bool {
        let locationApproved = locationManager.status == .authorizedAlways || locationManager.status == .authorizedWhenInUse
        let cameraApproved = cameraManager.status == .authorized
        return locationApproved && cameraApproved
    }
}

// MARK: - Preview
// This provides a live preview of ContentView in Xcode's canvas.
#Preview {
    ContentView()
}
