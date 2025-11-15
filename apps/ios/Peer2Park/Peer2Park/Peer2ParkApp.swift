//
//  Peer2ParkApp.swift
//  Peer2Park
//
//  Created by Trent S on 10/6/25.
//

import SwiftUI

@main
struct Peer2ParkApp: App {
    @StateObject private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionManager)
        }
    }
}
