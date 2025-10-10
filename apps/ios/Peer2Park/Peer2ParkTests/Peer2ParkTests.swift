//
//  Peer2ParkTests.swift
//  Peer2ParkTests
//
//  Created by Trent S on 10/6/25.
//

import Testing
@testable import Peer2Park

struct Peer2ParkTests {

    
    @Test("API_BASE_URL key exists in Info.plist")
        func apiBaseURLExists() async throws {
            let url = AppConfig.apiBaseURL
            #expect(!url.absoluteString.isEmpty)
        }

        @Test("Environment flag matches active scheme")
        func environmentFlagMatchesScheme() async throws {
            #if DEBUG
            #expect(AppConfig.environment == .dev)
            #elseif BETA
            #expect(AppConfig.environment == .beta)
            #else
            #expect(AppConfig.environment == .prod)
            #endif
        }
}
