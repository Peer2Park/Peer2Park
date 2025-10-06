import SwiftUI
import Peer2ParkNetworking

struct ContentView: View {
    @State private var status = "…"
    private let client = APIClient(baseURL: AppConfig.apiBaseURL)

    var body: some View {
        VStack(spacing: 12) {
            Text("Env: \(AppConfig.environment.rawValue)")
            Text("Base: \(AppConfig.apiBaseURL.absoluteString)").font(.footnote)
            Text("Health: \(status)")
            Button("Ping /health") { Task { await ping() } }
        }.padding()
        .task { await ping() }
    }

    @MainActor
    private func ping() async {
        do { status = try await client.health() }
        catch { status = "error: \(error.localizedDescription)" }
    }
}
