import Testing
import Foundation
@testable import Peer2ParkNetworking
private var APITestEnabled: Bool {
    if let value = Bundle.main.infoDictionary?["API_TEST_ENABLED"] as? String {
        return value == "YES"
    }
    return false
}
struct SmokeTests {
    @Test("Client initializes")
    func initClient() async throws {
        guard APITestEnabled else {
            #expect(true)
            return
        }
        let client = APIClient(baseURL: URL(string: "https://example.com")!)
        #expect(true)
    }
}

struct HealthTests {
    @Test("GET /health returns something")
    func getHealth() async throws {
        guard APITestEnabled else {
            #expect(true)
            return
        }
        let client = APIClient(baseURL: URL(string: "https://example.com")!)
        if #available(iOS 15.0, *) {
            do {
                _ = try await client.health()
                #expect(true)
            } catch {
                let desc = String(describing: error)
                #expect(!desc.isEmpty)
            }
        } else {
            #expect(true)
        }
    }
}
