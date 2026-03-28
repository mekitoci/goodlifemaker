import SwiftUI
import SwiftData
import BackgroundTasks
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct SetRestApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackupScheduler.taskID,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            SetRestApp.handleMidnightBackup(task: processingTask)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
#if canImport(GoogleSignIn)
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
#endif
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await SetRestApp.autoBackupIfNeeded() }
                    }
                }
        }
        .modelContainer(for: [WorkoutSession.self, WorkoutSet.self])
    }

    // 前景自動備份：app 開啟時，若今天尚未備份且啟用了自動備份，觸發一次
    static func autoBackupIfNeeded() async {
        guard BackupScheduler.isAutoBackupEnabled,
              UserDefaults.standard.bool(forKey: "google_drive_connected"),
              !BackupScheduler.wasBackedUpToday() else { return }

        do {
            let container = try ModelContainer(for: WorkoutSession.self, WorkoutSet.self)
            let context = ModelContext(container)
            let sessions = try context.fetch(
                FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            )
            let appState = AppState()
            let payload = buildBackupPayload(sessions: sessions, appState: appState)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)

            let service = GoogleDriveService()
            let restored = await service.restoreConnectionIfPossible()
            guard restored else { return }

            let fileName = "SetRest-auto-\(Int(Date().timeIntervalSince1970)).json"
            _ = try await service.uploadBackup(fileName: fileName, jsonData: data)
            BackupScheduler.recordBackupNow()
            BackupScheduler.scheduleNextMidnight()
        } catch {
            // 靜默失敗，不干擾使用者
        }
    }

    // 背景任務處理（每天凌晨 00:00 後由 iOS 排程觸發）
    private static func handleMidnightBackup(task: BGProcessingTask) {
        let taskHandle = Task {
            await autoBackupIfNeeded()
            task.setTaskCompleted(success: true)
            BackupScheduler.scheduleNextMidnight()
        }
        task.expirationHandler = {
            taskHandle.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
