//
//  Peer2ParkApp.swift
//  Peer2Park
//
//  Created by Trent S on 10/6/25.
//

import SwiftUI

@main
struct Peer2ParkApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
