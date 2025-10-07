import SwiftUI
import Peer2ParkNetworking

struct ContentView: View {
    @State private var status = "…"
    @StateObject private var locationManager = LocationManager()
    private let client = APIClient(baseURL: AppConfig.apiBaseURL)
    var body: some View {
        VStack(spacing: 12) {
            // App Icon Image
            Image("peer2park")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 180, height: 180)
                .cornerRadius(16)
            
            Text("Env: \(AppConfig.environment.rawValue)")
            Text("Base: \(AppConfig.apiBaseURL.absoluteString)").font(.footnote)
            Text("Health: \(status)")
            Button("Ping /health") { Task { await ping() } }
            
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
        .task { await ping() }
    }

    @MainActor
    private func ping() async {
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
