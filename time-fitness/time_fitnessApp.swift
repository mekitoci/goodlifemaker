//
//  time_fitnessApp.swift
//  time-fitness
//
//  Created by yang on 2026/3/14.
//

import SwiftUI

@main
struct time_fitnessApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
