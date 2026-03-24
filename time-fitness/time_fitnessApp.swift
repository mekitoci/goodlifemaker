import SwiftUI
import SwiftData
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct SetRestApp: App {

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
