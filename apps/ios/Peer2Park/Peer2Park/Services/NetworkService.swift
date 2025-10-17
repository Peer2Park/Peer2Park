//
//  NetworkService.swift
//  Peer2Park
//
//  Created by Trent S on 10/6/25.
//

import Foundation
import Peer2ParkNetworking
@MainActor
final class NetworkService: ObservableObject {
    private let client = APIClient(baseURL: AppConfig.apiBaseURL)
    @Published var healthStatus = "Not checked"

    func pingHealth() async {
        do {
            let text = try await client.health()
            healthStatus = "✅ \(text)"
        } catch {
            healthStatus = "❌ \(error.localizedDescription)"
        }
    }
}
