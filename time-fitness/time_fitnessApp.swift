import SwiftUI
import SwiftData

@main
struct PotlyApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [WorkoutSession.self, WorkoutSet.self])
    }
}
