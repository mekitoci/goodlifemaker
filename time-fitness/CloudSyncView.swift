import SwiftUI
import SwiftData
import UIKit
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(GoogleAPIClientForREST_Drive)
import GoogleAPIClientForREST_Drive
import GTMSessionFetcherCore
#endif

private struct AppBackupSetPayload: Codable {
    var id: UUID
    var setNumber: Int
    var reps: Int
    var weightKg: Double
    var completedAt: Date
    var supabaseID: String?
}

private struct AppBackupSessionPayload: Codable {
    var id: UUID
    var exerciseName: String
    var muscleGroup: String
    var date: Date
    var totalSets: Int
    var notes: String
    var sets: [AppBackupSetPayload]
    var supabaseID: String?
    var syncedAt: Date?
    var isDirty: Bool
}

private struct AppBackupPayload: Codable {
    var schemaVersion: Int = 2
    var exportedAt: Date
    var appState: AppState.LocalBackupSnapshot
    var workouts: [AppBackupSessionPayload]
}

struct CloudSyncSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]

    let pageBg: Color
    let surface: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color

    @AppStorage("google_drive_connected") private var googleDriveConnected: Bool = false

    @State private var service = GoogleDriveService()
    @State private var isWorking: Bool = false
    @State private var statusText: String = "尚未開始同步"
    @State private var statusIsError: Bool = false

    private func setStatus(_ text: String, error: Bool = false) {
        statusText = text
        statusIsError = error
    }

    private func makeBackupPayload() -> AppBackupPayload {
        let sessions: [AppBackupSessionPayload] = workoutSessions.map { s in
            let sets = s.sets
                .sorted(by: { $0.setNumber < $1.setNumber })
                .map { set in
                    AppBackupSetPayload(
                        id: set.id,
                        setNumber: set.setNumber,
                        reps: set.reps,
                        weightKg: set.weightKg,
                        completedAt: set.completedAt,
                        supabaseID: set.supabaseID
                    )
                }
            return AppBackupSessionPayload(
                id: s.id,
                exerciseName: s.exerciseName,
                muscleGroup: s.muscleGroup,
                date: s.date,
                totalSets: s.totalSets,
                notes: s.notes,
                sets: sets,
                supabaseID: s.supabaseID,
                syncedAt: s.syncedAt,
                isDirty: s.isDirty
            )
        }
        return AppBackupPayload(
            exportedAt: .now,
            appState: state.makeLocalBackupSnapshot(),
            workouts: sessions
        )
    }

    private func merge(from payload: AppBackupPayload) throws {
        // 1) Merge UserDefaults-backed app state (non-destructive)
        let remote = payload.appState

        // Exercises: merge by id, fallback by group+name
        var mergedExercises = state.exercises
        for ex in remote.exercises {
            if let idx = mergedExercises.firstIndex(where: { $0.id == ex.id }) {
                mergedExercises[idx] = ex
                continue
            }
            let sameName = mergedExercises.contains {
                $0.muscleGroup == ex.muscleGroup &&
                $0.name.compare(ex.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
            if !sameName { mergedExercises.append(ex) }
        }
        state.exercises = mergedExercises

        // Workout plans: merge by id
        var mergedPlans = state.workoutPlans
        for plan in remote.workoutPlans {
            if let idx = mergedPlans.firstIndex(where: { $0.id == plan.id }) {
                mergedPlans[idx] = plan
            } else {
                mergedPlans.append(plan)
            }
        }
        state.workoutPlans = mergedPlans

        state.hasSelectedPlant = state.hasSelectedPlant || remote.hasSelectedPlant
        if !state.hasSelectedPlant, remote.hasSelectedPlant {
            state.selectedPlantID = remote.selectedPlantID
        }
        state.plantHydration = max(state.plantHydration, remote.plantHydration)
        state.mustSwitchPot = state.mustSwitchPot || remote.mustSwitchPot

        var mergedPlantCounts = state.plantCompletionCounts
        for (plantID, count) in remote.plantCompletionCounts {
            mergedPlantCounts[plantID] = max(mergedPlantCounts[plantID] ?? 0, count)
        }
        state.plantCompletionCounts = mergedPlantCounts

        var plantingMap = Dictionary(uniqueKeysWithValues: state.plantingRecords.map { ($0.id, $0) })
        for rec in remote.plantingRecords where plantingMap[rec.id] == nil {
            plantingMap[rec.id] = rec
        }
        state.plantingRecords = plantingMap.values.sorted(by: { $0.completedAt > $1.completedAt })

        if state.lastPotRewardMessage.isEmpty {
            state.lastPotRewardMessage = remote.lastPotRewardMessage
        }
        state.totalSetsCompleted = max(state.totalSetsCompleted, remote.totalSetsCompleted)
        state.lastWorkoutTimestamp = max(state.lastWorkoutTimestamp, remote.lastWorkoutTimestamp)
        state.todayCalories = max(state.todayCalories, remote.todayCalories)
        state.lifetimeCalories = max(state.lifetimeCalories, remote.lifetimeCalories)
        state.todaySets = max(state.todaySets, remote.todaySets)
        state.workoutStreak = max(state.workoutStreak, remote.workoutStreak)

        if state.lastExerciseName.isEmpty {
            state.lastExerciseName = remote.lastExerciseName
        }
        if state.lastWeight <= 0 {
            state.lastWeight = remote.lastWeight
        }
        state.lastReps = max(state.lastReps, remote.lastReps)

        var mergedDiet = state.dietStatusByDate
        for (key, value) in remote.dietStatusByDate where mergedDiet[key] == nil {
            mergedDiet[key] = value
        }
        state.dietStatusByDate = mergedDiet

        let cal = Calendar.current
        var weightByDay: [Date: WeightLogEntry] = [:]
        for item in state.weightLogs {
            let day = cal.startOfDay(for: item.date)
            weightByDay[day] = item
        }
        for item in remote.weightLogs {
            let day = cal.startOfDay(for: item.date)
            if weightByDay[day] == nil { weightByDay[day] = item }
        }
        state.weightLogs = weightByDay.values.sorted(by: { $0.date < $1.date })

        // 2) Merge SwiftData workout sessions (non-destructive)
        var existingByID = Dictionary(uniqueKeysWithValues: workoutSessions.map { ($0.id, $0) })

        for s in payload.workouts {
            if let existing = existingByID[s.id] {
                existing.exerciseName = s.exerciseName
                existing.muscleGroup = s.muscleGroup
                existing.date = s.date
                existing.totalSets = max(existing.totalSets, s.totalSets)
                if existing.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    existing.notes = s.notes
                }
                if existing.supabaseID == nil { existing.supabaseID = s.supabaseID }
                if let remoteSync = s.syncedAt {
                    if let localSync = existing.syncedAt {
                        existing.syncedAt = max(localSync, remoteSync)
                    } else {
                        existing.syncedAt = remoteSync
                    }
                }
                existing.isDirty = existing.isDirty || s.isDirty

                var existingSetsByID = Dictionary(uniqueKeysWithValues: existing.sets.map { ($0.id, $0) })
                for item in s.sets {
                    if let localSet = existingSetsByID[item.id] {
                        localSet.setNumber = item.setNumber
                        localSet.reps = item.reps
                        localSet.weightKg = item.weightKg
                        localSet.completedAt = item.completedAt
                        if localSet.supabaseID == nil { localSet.supabaseID = item.supabaseID }
                    } else {
                        let set = WorkoutSet(
                            setNumber: item.setNumber,
                            reps: item.reps,
                            weightKg: item.weightKg,
                            completedAt: item.completedAt
                        )
                        set.id = item.id
                        set.supabaseID = item.supabaseID
                        set.session = existing
                        modelContext.insert(set)
                        existing.sets.append(set)
                        existingSetsByID[set.id] = set
                    }
                }
            } else {
                let session = WorkoutSession(
                    exerciseName: s.exerciseName,
                    muscleGroup: s.muscleGroup,
                    date: s.date,
                    totalSets: s.totalSets,
                    notes: s.notes
                )
                session.id = s.id
                session.supabaseID = s.supabaseID
                session.syncedAt = s.syncedAt
                session.isDirty = s.isDirty
                modelContext.insert(session)
                existingByID[session.id] = session

                for item in s.sets {
                    let set = WorkoutSet(
                        setNumber: item.setNumber,
                        reps: item.reps,
                        weightKg: item.weightKg,
                        completedAt: item.completedAt
                    )
                    set.id = item.id
                    set.supabaseID = item.supabaseID
                    set.session = session
                    modelContext.insert(set)
                    session.sets.append(set)
                }
            }
        }

        try modelContext.save()
    }

    private func uploadToDrive() async {
        guard googleDriveConnected else {
            setStatus("請先點「Google Login 連線」完成授權。", error: true)
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            setStatus("準備打包資料...")
            let payload = makeBackupPayload()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            let fileName = "potly-backup-\(Int(Date().timeIntervalSince1970)).json"
            setStatus("上傳至 Google Drive...")
            let fileID = try await service.uploadBackup(
                fileName: fileName,
                jsonData: data
            )
            setStatus("上傳成功，Drive 檔案 ID：\(fileID)")
        } catch {
            setStatus("上傳失敗：\(error.localizedDescription)", error: true)
        }
    }

    private func connectGoogleDrive() async {
        isWorking = true
        defer { isWorking = false }
        do {
            setStatus("開啟 Google Login...")
            let folderPath = try await service.connectAndPrepareFolder()
            googleDriveConnected = true
            setStatus("連線成功，已建立/定位資料夾：\(folderPath)")
        } catch {
            googleDriveConnected = false
            setStatus("連線失敗：\(error.localizedDescription)", error: true)
        }
    }

    private func restoreFromDrive() async {
        guard googleDriveConnected else {
            setStatus("請先點「Google Login 連線」完成授權。", error: true)
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            setStatus("下載最新備份...")
            let data = try await service.downloadLatestBackup()
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(AppBackupPayload.self, from: data)
            try merge(from: payload)
            setStatus("匯入完成：已與本機資料合併。")
        } catch {
            setStatus("下載/匯入失敗：\(error.localizedDescription)", error: true)
        }
    }

    private func refreshGoogleSignInStateOnAppear() async {
        let restored = await service.restoreConnectionIfPossible()
        googleDriveConnected = restored
        if restored {
            setStatus("已恢復 Google 登入狀態")
        } else {
            setStatus("尚未連線 Google Drive")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                pageBg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Google Drive")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                            Text("先登入 Google 並授權 Drive 權限，系統會自動建立路徑 `/Log/Potly/` 存放備份檔。")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.86))
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                guard !googleDriveConnected else { return }
                                Task { await connectGoogleDrive() }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: googleDriveConnected ? "checkmark.circle.fill" : "person.crop.circle.badge.checkmark")
                                        .font(.headline)
                                    Text(googleDriveConnected ? "已連線 Google Drive" : "Google 登入")
                                        .font(.subheadline.bold())
                                    Spacer()
                                    if !googleDriveConnected {
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                                .background(
                                    LinearGradient(
                                        colors: googleDriveConnected
                                            ? [Color(red: 0.21, green: 0.58, blue: 0.43), Color(red: 0.18, green: 0.52, blue: 0.38)]
                                            : [Color(red: 0.16, green: 0.42, blue: 0.43), Color(red: 0.13, green: 0.36, blue: 0.36)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isWorking || googleDriveConnected)
                            .opacity((isWorking || googleDriveConnected) ? 0.78 : 1)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                        VStack(spacing: 10) {
                            Button {
                                Task { await uploadToDrive() }
                            } label: {
                                Label("匯出全部資料到 Google Drive", systemImage: "arrow.up.doc.fill")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color(red: 0.20, green: 0.40, blue: 0.36))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(isWorking)

                            Button {
                                Task { await restoreFromDrive() }
                            } label: {
                                Label("從 Google Drive 下載並還原", systemImage: "arrow.down.doc.fill")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(red: 0.36, green: 0.47, blue: 0.88), Color(red: 0.28, green: 0.36, blue: 0.74)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(isWorking || !googleDriveConnected)
                            .opacity(googleDriveConnected ? 1 : 0.55)
                        }
                        .padding(12)
                        .background(Color(red: 0.23, green: 0.49, blue: 0.47).opacity(0.94))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )

                        HStack(alignment: .top, spacing: 8) {
                            if isWorking {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: statusIsError ? "xmark.octagon.fill" : "checkmark.circle.fill")
                                    .foregroundStyle(statusIsError ? Color.red.opacity(0.9) : accent)
                            }
                            Text(statusText)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.88))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("雲端同步")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(pageBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .task {
            await refreshGoogleSignInStateOnAppear()
        }
    }
}

private final class GoogleDriveService {
    private let potlyFolderIDKey = "google_drive_potly_folder_id"

    private enum DriveError: LocalizedError {
        case sdkMissing
        case signInFailed
        case notConfigured
        case noBackupFile
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .sdkMissing:
                return "缺少 GoogleSignIn 或 GoogleAPIClientForREST 套件，請先加到 Xcode。"
            case .signInFailed:
                return "Google 登入失敗。"
            case .notConfigured:
                return "請先在專案設定好 GoogleSignIn（包含 GoogleService-Info.plist）。"
            case .noBackupFile:
                return "在 /Log/Potly 找不到備份檔。"
            case .apiError(let msg):
                return msg
            }
        }
    }

#if canImport(GoogleSignIn) && canImport(GoogleAPIClientForREST_Drive)
    private let driveService = GTLRDriveService()

    private func ensureSignInConfiguration() -> Bool {
        if GIDSignIn.sharedInstance.configuration != nil { return true }
        guard let clientID = resolvedGoogleClientID() else { return false }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        return true
    }

    private func resolvedGoogleClientID() -> String? {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") {
            let value = (raw as? String) ?? String(describing: raw)
            if value.contains(".apps.googleusercontent.com") { return value }
        }

        for plistPath in Bundle.main.paths(forResourcesOfType: "plist", inDirectory: nil) {
            guard let dict = NSDictionary(contentsOfFile: plistPath) else { continue }
            guard let raw = dict["CLIENT_ID"] else { continue }
            let value = (raw as? String) ?? String(describing: raw)
            if value.contains(".apps.googleusercontent.com") { return value }
        }
        return nil
    }

    private func currentPresentingViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
        var root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let presented = root?.presentedViewController {
            root = presented
        }
        return root
    }

    private func signInAndAuthorize() async throws -> GIDGoogleUser {
        if !ensureSignInConfiguration() {
            throw DriveError.notConfigured
        }

        if let existing = GIDSignIn.sharedInstance.currentUser {
            try await existing.refreshTokensIfNeeded()
            driveService.authorizer = existing.fetcherAuthorizer
            return existing
        }

        guard let vc = currentPresentingViewController() else {
            throw DriveError.notConfigured
        }

        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: vc,
                hint: nil,
                additionalScopes: [kGTLRAuthScopeDriveFile]
            ) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let user = result?.user else {
                    continuation.resume(throwing: DriveError.signInFailed)
                    return
                }
                self.driveService.authorizer = user.fetcherAuthorizer
                continuation.resume(returning: user)
            }
        }
    }

    func restoreConnectionIfPossible() async -> Bool {
        guard ensureSignInConfiguration() else { return false }

        if let existing = GIDSignIn.sharedInstance.currentUser {
            driveService.authorizer = existing.fetcherAuthorizer
            return true
        }

        return await withCheckedContinuation { continuation in
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, _ in
                guard let user else {
                    continuation.resume(returning: false)
                    return
                }
                self.driveService.authorizer = user.fetcherAuthorizer
                continuation.resume(returning: true)
            }
        }
    }

    private func executeQuery<T: GTLRQueryProtocol>(_ query: T) async throws -> Any {
        try await withCheckedThrowingContinuation { continuation in
            driveService.executeQuery(query) { _, object, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: object as Any)
                }
            }
        }
    }

    private func findFolderID(name: String, parentID: String) async throws -> String? {
        let q = "mimeType='application/vnd.google-apps.folder' and trashed=false and name='\(name)' and '\(parentID)' in parents"
        let query = GTLRDriveQuery_FilesList.query()
        query.q = q
        query.pageSize = 1
        query.fields = "files(id,name)"
        let obj = try await executeQuery(query)
        guard let list = obj as? GTLRDrive_FileList else { return nil }
        return list.files?.first?.identifier
    }

    private func createFolder(name: String, parentID: String) async throws -> String {
        let file = GTLRDrive_File()
        file.name = name
        file.mimeType = "application/vnd.google-apps.folder"
        file.parents = [parentID]
        let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: nil)
        query.fields = "id,name"
        let obj = try await executeQuery(query)
        guard let created = obj as? GTLRDrive_File, let id = created.identifier else {
            throw DriveError.apiError("建立資料夾成功但無法取得 ID")
        }
        return id
    }

    private func ensureFolder(name: String, parentID: String) async throws -> String {
        if let existing = try await findFolderID(name: name, parentID: parentID) {
            return existing
        }
        return try await createFolder(name: name, parentID: parentID)
    }

    private func ensurePotlyFolderID() async throws -> String {
        if let cached = UserDefaults.standard.string(forKey: potlyFolderIDKey), !cached.isEmpty {
            return cached
        }
        let logID = try await ensureFolder(name: "Log", parentID: "root")
        let potlyID = try await ensureFolder(name: "Potly", parentID: logID)
        UserDefaults.standard.set(potlyID, forKey: potlyFolderIDKey)
        return potlyID
    }

    func connectAndPrepareFolder() async throws -> String {
        _ = try await signInAndAuthorize()
        _ = try await ensurePotlyFolderID()
        return "/Log/Potly/"
    }

    func uploadBackup(fileName: String, jsonData: Data) async throws -> String {
        _ = try await signInAndAuthorize()
        let folderID = try await ensurePotlyFolderID()

        let file = GTLRDrive_File()
        file.name = fileName
        file.mimeType = "application/json"
        file.parents = [folderID]
        let upload = GTLRUploadParameters(data: jsonData, mimeType: "application/json")
        let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: upload)
        query.fields = "id,name"
        let obj = try await executeQuery(query)
        guard let created = obj as? GTLRDrive_File, let id = created.identifier else {
            throw DriveError.apiError("上傳成功但未回傳 file id")
        }
        return id
    }

    func downloadLatestBackup() async throws -> Data {
        _ = try await signInAndAuthorize()
        let folderID = try await ensurePotlyFolderID()

        let list = GTLRDriveQuery_FilesList.query()
        // 以資料夾內「最新修改時間」的 JSON 檔作為還原來源
        list.q = "mimeType='application/json' and trashed=false and '\(folderID)' in parents"
        list.orderBy = "modifiedTime desc"
        list.pageSize = 1
        list.fields = "files(id,name,modifiedTime)"
        let listObj = try await executeQuery(list)
        guard let files = (listObj as? GTLRDrive_FileList)?.files,
              let first = files.first,
              let fileID = first.identifier else {
            throw DriveError.noBackupFile
        }

        let get = GTLRDriveQuery_FilesGet.queryForMedia(withFileId: fileID)
        let mediaObj = try await executeQuery(get)
        if let dataObj = mediaObj as? GTLRDataObject {
            return dataObj.data
        }
        throw DriveError.apiError("下載備份檔失敗")
    }
#else
    func restoreConnectionIfPossible() async -> Bool {
        false
    }

    func connectAndPrepareFolder() async throws -> String {
        throw DriveError.sdkMissing
    }

    func uploadBackup(fileName: String, jsonData: Data) async throws -> String {
        _ = fileName
        _ = jsonData
        throw DriveError.sdkMissing
    }

    func downloadLatestBackup() async throws -> Data {
        throw DriveError.sdkMissing
    }
#endif
}
