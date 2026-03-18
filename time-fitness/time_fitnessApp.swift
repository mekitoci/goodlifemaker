import SwiftUI
import SwiftData

@main
struct time_fitnessApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [WorkoutSession.self, WorkoutSet.self])
    }
}
