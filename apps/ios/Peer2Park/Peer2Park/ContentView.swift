import SwiftUI
import Peer2ParkNetworking
import AVFoundation
struct ContentView: View {
    @State private var status = "…"
    @StateObject private var locationManager = LocationManager()
    @StateObject private var cameraManager = CameraManager()
    @State private var showLiveVideo = false
    private let client: APIClient?
    private var APITestEnabled: Bool {
        if let value = Bundle.main.infoDictionary?["API_TEST_ENABLED"] as? String {
            return value == "YES"
        }
        return false
    }
    
    init() {
        // Use a local variable to check API_TEST_ENABLED before initializing client
        let apiTestEnabled: Bool
        if let value = Bundle.main.infoDictionary?["API_TEST_ENABLED"] as? String {
            apiTestEnabled = value == "YES"
        } else {
            apiTestEnabled = false
        }
        if apiTestEnabled {
            self.client = APIClient(baseURL: AppConfig.apiBaseURL)
        } else {
            self.client = nil
        }
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ZStack {
                    Color(.white)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        // App Icon Image
                        Image("peer2park")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 180, height: 180)
                            .cornerRadius(20)
                        Text("Welcome to Parking Reimagined")
                            .font(Font.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        if APITestEnabled {
                            Text("Env: \(AppConfig.environment.rawValue)")
                            Text("Base: \(AppConfig.apiBaseURL.absoluteString)").font(.footnote)
                            Text("Health: \(status)")
                        }
                        // Bool --> good to go
                        // Location permission status and button
                        Text("Location Status: \(locationStatusText)")
                            .font(.caption)
                        if locationManager.status == .denied {
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
                        }
                        else {
                            Button("Request Location Permission") {
                                locationManager.requestPermission()
                            }
                        }
                        
                        
                        // Camera permission status and button
                        Text("Camera Status: \(cameraStatusText)")
                            .font(.caption)
                        if cameraManager.status == .denied {
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
                            
                        }
                        else {
                            Button("Request Camera Permission") {
                                cameraManager.requestPermission()
                            }
                        }
                        if permissionsApproved {
                            Text("All permissions granted! Ready to go.")
                                .foregroundStyle(Color.green)
                            Button("Show Live Video") {
                                showLiveVideo = true
                            }
                            .foregroundStyle(Color.blue)
                            .padding(.top)
                            
                            NavigationLink(destination: UserMapView()) {
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
            .task { await ping() }
            .navigationDestination(isPresented: $showLiveVideo) {
                LiveVideoView()
            }
        }
    }
    
    @MainActor
    private func ping() async {
        guard let client = client else {
            status = "API test disabled"
            return
        }
        do { status = try await client.health() }
        catch { status = "error: \(error.localizedDescription)" }
    }
    
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
    
    private var cameraStatusText: String {
        switch cameraManager.status {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .restricted: return "Restricted"
        @unknown default: return "Unknown"
        }
    }
    
    private var permissionsApproved: Bool {
        let locationApproved = locationManager.status == .authorizedAlways || locationManager.status == .authorizedWhenInUse
        let cameraApproved = cameraManager.status == .authorized
        return locationApproved && cameraApproved
    }
}

#Preview {
    ContentView()
}
