import SwiftUI
import SwiftData
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct PotlyApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
#if canImport(GoogleSignIn)
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
#endif
        }
        .modelContainer(for: [WorkoutSession.self, WorkoutSet.self])
    }
}
