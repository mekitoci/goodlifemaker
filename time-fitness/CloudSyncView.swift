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

    private func restore(from payload: AppBackupPayload) throws {
        state.applyLocalBackupSnapshot(payload.appState)
        for s in workoutSessions {
            modelContext.delete(s)
        }
        for s in payload.workouts {
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
            try restore(from: payload)
            setStatus("匯入完成：已覆蓋本機資料。")
        } catch {
            setStatus("下載/匯入失敗：\(error.localizedDescription)", error: true)
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
                            HStack(spacing: 8) {
                                Image(systemName: googleDriveConnected ? "checkmark.seal.fill" : "xmark.seal.fill")
                                    .foregroundStyle(googleDriveConnected ? Color.green : Color.orange)
                                Text(googleDriveConnected ? "已連線 Google Drive" : "尚未連線 Google Drive")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(textPrimary)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Button {
                                Task { await connectGoogleDrive() }
                            } label: {
                                Label("Google 登入", systemImage: "person.crop.circle.badge.checkmark")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(red: 0.22, green: 0.42, blue: 0.38))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(isWorking)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(spacing: 10) {
                            Button {
                                Task { await uploadToDrive() }
                            } label: {
                                Label("匯出全部資料到 Google Drive", systemImage: "arrow.up.doc.fill")
                                    .font(.headline.bold())
                                    .foregroundStyle(Color(red: 0.22, green: 0.42, blue: 0.38))
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
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(accent)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(isWorking || !googleDriveConnected)
                            .opacity(googleDriveConnected ? 1 : 0.55)
                        }
                        .padding(12)
                        .background(Color(red: 0.30, green: 0.56, blue: 0.52).opacity(0.94))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
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
                        .background(Color.white.opacity(0.12))
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
        if GIDSignIn.sharedInstance.configuration == nil {
            guard let clientID = resolvedGoogleClientID() else {
                throw DriveError.notConfigured
            }
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
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
        list.q = "name contains 'potly-backup-' and trashed=false and '\(folderID)' in parents"
        list.orderBy = "modifiedTime desc"
        list.pageSize = 1
        list.fields = "files(id,name)"
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
