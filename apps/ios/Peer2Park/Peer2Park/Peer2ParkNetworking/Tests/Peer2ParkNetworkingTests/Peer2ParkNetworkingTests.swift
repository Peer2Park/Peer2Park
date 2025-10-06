import Testing
import Foundation
@testable import Peer2ParkNetworking

struct SmokeTests {
    @Test("Client initializes")
    func initClient() async throws {
        let client = APIClient(baseURL: URL(string: "https://example.com")!)
        #expect(client != nil)
    }
}
