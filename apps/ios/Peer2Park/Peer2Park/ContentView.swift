import SwiftUI
import Peer2ParkNetworking

struct ContentView: View {
    @State private var status = "…"
    @StateObject private var locationManager = LocationManager()
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
                        Button("Ping /health") { Task { await ping() } }
                        
                        
                    }
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
                    } else {
                        Button("Request Location Permission") {
                            locationManager.requestPermission()
                        }
                    }
                }.padding()
            }
            
            
                
        }
        
        .task { await ping() }
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
}

#Preview {
    ContentView()
}
