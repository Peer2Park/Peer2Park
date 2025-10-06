import SwiftUI

struct ContentView: View {
    @StateObject private var network = NetworkService()

    var body: some View {
        VStack(spacing: 16) {
            Text("Environment: \(AppConfig.environment.rawValue)")
            Text("Base URL: \(AppConfig.apiBaseURL.absoluteString)")
                .font(.footnote)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Text(network.healthStatus)
                .font(.headline)
                .padding(.top)

            Button("Ping /health") {
                Task { await network.pingHealth() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .task { await network.pingHealth() } // auto-ping on launch
    }
}
