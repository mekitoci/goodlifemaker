import SwiftUI
import UIKit
import Observation
import ActivityKit
import SwiftData
import HealthKit


enum AchievementMetric {
    case totalActions
    case workoutStreak
    case todayCalories
    case lifetimeCalories
    case totalPlantCompletions
    case uniquePlantsCompleted
    case totalPlans
    case customExercises
}

struct AchievementDefinition: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let metric: AchievementMetric
    let target: Int
    let points: Int
}

struct AchievementProgressItem: Identifiable {
    let definition: AchievementDefinition
    let current: Int
    let isUnlocked: Bool

    var id: String { definition.id }
    var progress: Double {
        guard definition.target > 0 else { return 1 }
        return min(Double(current) / Double(definition.target), 1)
    }
    var progressText: String {
        "\(min(current, definition.target))/\(definition.target)"
    }
}

// MARK: - AppState
// Single source of truth for the entire app.
// Injected as @Environment(AppState.self) from ContentView.

@Observable
final class AppState {
    struct LocalBackupSnapshot: Codable {
        var exercises: [Exercise]
        var workoutPlans: [WorkoutPlan]
        var selectedPlantID: Int
        var hasSelectedPlant: Bool
        var plantHydration: Double
        var mustSwitchPot: Bool
        var plantCompletionCounts: [Int: Int]
        var plantingRecords: [PlantingRecord]
        var lastPotRewardMessage: String
        var totalSetsCompleted: Int
        var lastWorkoutTimestamp: Double
        var todayCalories: Double
        var todayCaloriesDate: Double
        var lifetimeCalories: Double
        var todaySets: Int
        var todaySetsDate: Double
        var workoutStreak: Int
        var lastStreakTimestamp: Double
        var lastExerciseName: String
        var lastWeight: Double
        var lastReps: Int
        var weightUnitRaw: String
        var healthKitRequested: Bool
        var dietStatusByDate: [String: String]
        var weightLogs: [WeightLogEntry]
    }

    private static let healthKitRequestedKey = "healthkit_requested_v1"
    private let healthStore = HKHealthStore()
    private var healthKitRequested: Bool = UserDefaults.standard.bool(forKey: AppState.healthKitRequestedKey) {
        didSet { UserDefaults.standard.set(healthKitRequested, forKey: AppState.healthKitRequestedKey) }
    }
    private var lastHealthKitRefreshAt: Date = .distantPast
    private var lastHealthKitMinuteStamp: Int = -1

    func makeLocalBackupSnapshot() -> LocalBackupSnapshot {
        LocalBackupSnapshot(
            exercises: exercises,
            workoutPlans: workoutPlans,
            selectedPlantID: selectedPlantID,
            hasSelectedPlant: hasSelectedPlant,
            plantHydration: plantHydration,
            mustSwitchPot: mustSwitchPot,
            plantCompletionCounts: plantCompletionCounts,
            plantingRecords: plantingRecords,
            lastPotRewardMessage: lastPotRewardMessage,
            totalSetsCompleted: totalSetsCompleted,
            lastWorkoutTimestamp: lastWorkoutTimestamp,
            todayCalories: todayCalories,
            todayCaloriesDate: UserDefaults.standard.double(forKey: "todayCaloriesDate"),
            lifetimeCalories: lifetimeCalories,
            todaySets: todaySets,
            todaySetsDate: UserDefaults.standard.double(forKey: "todaySetsDate"),
            workoutStreak: workoutStreak,
            lastStreakTimestamp: lastStreakTimestamp,
            lastExerciseName: lastExerciseName,
            lastWeight: lastWeight,
            lastReps: lastReps,
            weightUnitRaw: weightUnitRaw,
            healthKitRequested: healthKitRequested,
            dietStatusByDate: dietStatusByDate,
            weightLogs: weightLogs
        )
    }

    func applyLocalBackupSnapshot(_ snapshot: LocalBackupSnapshot) {
        exercises = snapshot.exercises
        workoutPlans = snapshot.workoutPlans
        selectedPlantID = snapshot.selectedPlantID
        hasSelectedPlant = snapshot.hasSelectedPlant
        plantHydration = snapshot.plantHydration
        mustSwitchPot = snapshot.mustSwitchPot
        plantCompletionCounts = snapshot.plantCompletionCounts
        plantingRecords = snapshot.plantingRecords
        lastPotRewardMessage = snapshot.lastPotRewardMessage
        totalSetsCompleted = snapshot.totalSetsCompleted
        lastWorkoutTimestamp = snapshot.lastWorkoutTimestamp
        todayCalories = snapshot.todayCalories
        UserDefaults.standard.set(snapshot.todayCaloriesDate, forKey: "todayCaloriesDate")
        lifetimeCalories = snapshot.lifetimeCalories
        todaySets = snapshot.todaySets
        UserDefaults.standard.set(snapshot.todaySetsDate, forKey: "todaySetsDate")
        workoutStreak = snapshot.workoutStreak
        lastStreakTimestamp = snapshot.lastStreakTimestamp
        lastExerciseName = snapshot.lastExerciseName
        lastWeight = snapshot.lastWeight
        lastReps = snapshot.lastReps
        weightUnitRaw = snapshot.weightUnitRaw
        healthKitRequested = snapshot.healthKitRequested
        dietStatusByDate = snapshot.dietStatusByDate
        weightLogs = snapshot.weightLogs
    }

    // MARK: - Exercise catalog（支援 CRUD，UserDefaults 持久化）

    private static let exercisesKey = "user_exercises_v1"

    private struct ExerciseSeed {
        let name: String
        let sets: Int
        let rest: Int
    }

    /// 依肌群分組，後續擴充字典只需要在這裡加條目
    private static let defaultExerciseCatalog: [String: [ExerciseSeed]] = [
        "胸": [
            .init(name: "槓鈴臥推", sets: 4, rest: 90),
            .init(name: "啞鈴臥推", sets: 4, rest: 90),
            .init(name: "上斜啞鈴臥推", sets: 4, rest: 90),
            .init(name: "下斜臥推", sets: 4, rest: 90),
            .init(name: "啞鈴飛鳥", sets: 4, rest: 90),
            .init(name: "機械夾胸", sets: 4, rest: 75),
            .init(name: "機械胸推", sets: 4, rest: 90),
            .init(name: "機械上胸推", sets: 4, rest: 90),
            .init(name: "機械下胸推", sets: 4, rest: 90),
            .init(name: "機械平胸推", sets: 4, rest: 90),
            .init(name: "蝴蝶機夾胸", sets: 4, rest: 75),
            .init(name: "雙槓撐體", sets: 3, rest: 90)
        ],
        "背": [
            .init(name: "引體向上", sets: 4, rest: 90),
            .init(name: "高位下拉", sets: 4, rest: 90),
            .init(name: "坐姿划船", sets: 4, rest: 90),
            .init(name: "啞鈴划船", sets: 4, rest: 90),
            .init(name: "槓鈴划船", sets: 4, rest: 90),
            .init(name: "繩索划船", sets: 4, rest: 75),
            .init(name: "直臂下拉", sets: 3, rest: 60),
            .init(name: "機械划船", sets: 4, rest: 90),
            .init(name: "機械下拉", sets: 4, rest: 90),
            .init(name: "機械背闊下拉", sets: 4, rest: 90),
            .init(name: "機械反手下拉", sets: 4, rest: 90),
            .init(name: "面拉", sets: 3, rest: 60)
        ],
        "肩": [
            .init(name: "槓鈴肩推", sets: 4, rest: 90),
            .init(name: "啞鈴肩推", sets: 4, rest: 90),
            .init(name: "阿諾肩推", sets: 4, rest: 90),
            .init(name: "啞鈴側平舉", sets: 4, rest: 60),
            .init(name: "啞鈴前平舉", sets: 3, rest: 60),
            .init(name: "反向飛鳥", sets: 4, rest: 60),
            .init(name: "機械肩推", sets: 4, rest: 90),
            .init(name: "機械側平舉", sets: 4, rest: 60),
            .init(name: "機械後三角飛鳥", sets: 4, rest: 60),
            .init(name: "機械前平舉", sets: 3, rest: 60),
            .init(name: "直立划船", sets: 3, rest: 75)
        ],
        "手臂": [
            .init(name: "槓鈴二頭彎舉", sets: 3, rest: 60),
            .init(name: "啞鈴二頭彎舉", sets: 3, rest: 60),
            .init(name: "槌式彎舉", sets: 3, rest: 60),
            .init(name: "繩索彎舉", sets: 3, rest: 60),
            .init(name: "機械二頭彎舉", sets: 3, rest: 60),
            .init(name: "窄握臥推", sets: 4, rest: 90),
            .init(name: "繩索下壓", sets: 3, rest: 60),
            .init(name: "機械三頭下壓", sets: 3, rest: 60),
            .init(name: "機械雙臂屈伸", sets: 3, rest: 75),
            .init(name: "仰臥臂屈伸", sets: 3, rest: 60),
            .init(name: "啞鈴後三頭伸展", sets: 3, rest: 60)
        ],
        "腿": [
            .init(name: "深蹲", sets: 4, rest: 120),
            .init(name: "前蹲", sets: 4, rest: 120),
            .init(name: "硬舉", sets: 4, rest: 120),
            .init(name: "羅馬尼亞硬舉", sets: 4, rest: 90),
            .init(name: "腿推", sets: 4, rest: 90),
            .init(name: "腿屈伸", sets: 4, rest: 75),
            .init(name: "腿後勾", sets: 4, rest: 75),
            .init(name: "機械髖外展", sets: 3, rest: 60),
            .init(name: "機械髖內收", sets: 3, rest: 60),
            .init(name: "史密斯深蹲", sets: 4, rest: 90),
            .init(name: "史密斯弓箭步", sets: 3, rest: 90),
            .init(name: "機械臀推", sets: 4, rest: 90),
            .init(name: "機械提踵", sets: 4, rest: 60),
            .init(name: "保加利亞分腿蹲", sets: 3, rest: 90),
            .init(name: "弓箭步", sets: 3, rest: 75),
            .init(name: "臀推", sets: 4, rest: 90),
            .init(name: "提踵", sets: 4, rest: 60)
        ],
        "核心": [
            .init(name: "平板支撐", sets: 3, rest: 45),
            .init(name: "側平板", sets: 3, rest: 45),
            .init(name: "捲腹", sets: 3, rest: 45),
            .init(name: "仰臥抬腿", sets: 3, rest: 45),
            .init(name: "懸垂抬腿", sets: 3, rest: 60),
            .init(name: "俄羅斯轉體", sets: 3, rest: 45),
            .init(name: "機械捲腹", sets: 3, rest: 45),
            .init(name: "機械旋轉核心", sets: 3, rest: 45),
            .init(name: "死蟲", sets: 3, rest: 45)
        ]
    ]

    private static var defaultExercises: [Exercise] {
        defaultExerciseCatalog
            .sorted(by: { $0.key < $1.key })
            .flatMap { group, seeds in
                seeds.map {
                    Exercise(
                        name: $0.name,
                        muscleGroup: group,
                        defaultSets: $0.sets,
                        restSeconds: $0.rest
                    )
                }
            }
    }

    private static func cleanedExerciseName(_ raw: String) -> String {
        // 移除英文，保留中文與常見符號，並去掉空白
        let noEnglish = raw.replacingOccurrences(
            of: "[A-Za-z]+",
            with: "",
            options: .regularExpression
        )
        let noSpaces = noEnglish.replacingOccurrences(
            of: "\\s+",
            with: "",
            options: .regularExpression
        )
        return noSpaces.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func hasCJK(_ text: String) -> Bool {
        text.range(of: "[\\u4E00-\\u9FFF]", options: .regularExpression) != nil
    }

    private static func sanitizeExercises(_ source: [Exercise]) -> [Exercise] {
        var seen = Set<String>()
        var result: [Exercise] = []

        for ex in source {
            let name = cleanedExerciseName(ex.name)
            guard !name.isEmpty, hasCJK(name) else { continue }

            let group = ex.muscleGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "全身"
                : ex.muscleGroup
            let sets = max(1, ex.defaultSets)
            let rest = max(30, ex.restSeconds)
            let key = "\(group)|\(name)"
            guard seen.insert(key).inserted else { continue }

            result.append(
                Exercise(
                    id: ex.id,
                    name: name,
                    muscleGroup: group,
                    defaultSets: sets,
                    restSeconds: rest,
                    defaultWeightKg: max(0, ex.defaultWeightKg)
                )
            )
        }

        return result
    }

    private static func mergedExerciseDictionary(saved: [Exercise]) -> [Exercise] {
        var merged = sanitizeExercises(saved)
        var keys = Set(merged.map { "\($0.muscleGroup)|\($0.name)" })

        for ex in defaultExercises {
            let key = "\(ex.muscleGroup)|\(ex.name)"
            if keys.insert(key).inserted {
                merged.append(ex)
            }
        }
        return merged
    }

    var exercises: [Exercise] = [] {
        didSet { saveExercises() }
    }

    private func loadExercises() {
        if let data = UserDefaults.standard.data(forKey: Self.exercisesKey),
           let saved = try? JSONDecoder().decode([Exercise].self, from: data) {
            exercises = Self.mergedExerciseDictionary(saved: saved)
        } else {
            exercises = Self.defaultExercises
        }
    }

    private func saveExercises() {
        if let data = try? JSONEncoder().encode(exercises) {
            UserDefaults.standard.set(data, forKey: Self.exercisesKey)
        }
    }

    // MARK: Exercise CRUD

    func addExercise(_ exercise: Exercise) {
        let cleaned = Self.cleanedExerciseName(exercise.name)
        guard !cleaned.isEmpty, Self.hasCJK(cleaned) else { return }
        let normalized = Exercise(
            id: exercise.id,
            name: cleaned,
            muscleGroup: exercise.muscleGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "全身" : exercise.muscleGroup,
            defaultSets: max(1, exercise.defaultSets),
            restSeconds: max(30, exercise.restSeconds),
            defaultWeightKg: max(0, exercise.defaultWeightKg)
        )
        let key = "\(normalized.muscleGroup)|\(normalized.name)"
        if !exercises.contains(where: { "\($0.muscleGroup)|\($0.name)" == key }) {
            exercises.append(normalized)
        }
    }

    func updateExercise(_ exercise: Exercise) {
        if let idx = exercises.firstIndex(where: { $0.id == exercise.id }) {
            let cleaned = Self.cleanedExerciseName(exercise.name)
            guard !cleaned.isEmpty, Self.hasCJK(cleaned) else {
                exercises.remove(at: idx)
                return
            }
            exercises[idx] = Exercise(
                id: exercise.id,
                name: cleaned,
                muscleGroup: exercise.muscleGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "全身" : exercise.muscleGroup,
                defaultSets: max(1, exercise.defaultSets),
                restSeconds: max(30, exercise.restSeconds),
                defaultWeightKg: max(0, exercise.defaultWeightKg)
            )
        }
    }

    func deleteExercise(_ exercise: Exercise) {
        exercises.removeAll { $0.id == exercise.id }
    }

    /// 從「訓練菜單」快速新增動作時使用：
    /// - 保留原始名稱（包含英文）
    /// - 若同名動作已存在則直接回傳既有項目
    @discardableResult
    func upsertExerciseFromPlan(
        name rawName: String,
        muscleGroup rawGroup: String = "自訂",
        defaultSets: Int = 4,
        restSeconds: Int = 90
    ) -> Exercise {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let group = rawGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "自訂"
            : rawGroup.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = exercises.first(where: {
            $0.muscleGroup == group &&
            $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            return existing
        }

        let created = Exercise(
            id: UUID(),
            name: name.isEmpty ? "未命名動作" : name,
            muscleGroup: group,
            defaultSets: max(1, defaultSets),
            restSeconds: max(30, restSeconds),
            defaultWeightKg: 0
        )
        exercises.append(created)
        return created
    }

    // MARK: - Workout Plans

    private static let plansKey = "user_workout_plans_v1"
    private static let dietStatusLogsKey = "diet_status_logs_v1"
    private static let weightLogsKey = "weight_logs_v1"

    var workoutPlans: [WorkoutPlan] = [] {
        didSet { savePlans() }
    }

    // 目前正在執行的菜單隊列
    var activePlanQueue: [WorkoutPlanItem] = []
    var activePlanIndex: Int = 0

    var activePlanItem: WorkoutPlanItem? {
        guard !activePlanQueue.isEmpty, activePlanIndex < activePlanQueue.count else { return nil }
        return activePlanQueue[activePlanIndex]
    }

    var hasNextPlanItem: Bool {
        !activePlanQueue.isEmpty && activePlanIndex + 1 < activePlanQueue.count
    }

    func startPlan(_ plan: WorkoutPlan) {
        activePlanQueue = plan.items
        activePlanIndex = 0
        if let first = activePlanQueue.first, let ex = exercises.first(where: { $0.id == first.exerciseID }) {
            startExercise(
                ex,
                totalSetsOverride: first.sets,
                weightKgOverride: first.targetWeightKg,
                repsOverride: first.targetReps
            )
        } else if let first = activePlanQueue.first {
            // exercise was deleted but plan item still has name - create a temp exercise
            let tempEx = Exercise(id: first.exerciseID, name: first.exerciseName,
                                  muscleGroup: first.muscleGroup, defaultSets: first.sets, restSeconds: 90)
            startExercise(
                tempEx,
                totalSetsOverride: first.sets,
                weightKgOverride: first.targetWeightKg,
                repsOverride: first.targetReps
            )
        }
    }

    func advanceToNextPlanItem() {
        activePlanIndex += 1
        guard let next = activePlanItem else { return }
        let ex = exercises.first(where: { $0.id == next.exerciseID })
            ?? Exercise(id: next.exerciseID, name: next.exerciseName,
                        muscleGroup: next.muscleGroup, defaultSets: next.sets, restSeconds: 90)
        startExercise(
            ex,
            totalSetsOverride: next.sets,
            weightKgOverride: next.targetWeightKg,
            repsOverride: next.targetReps
        )
    }

    func clearActivePlan() {
        activePlanQueue = []
        activePlanIndex = 0
    }

    func addPlan(_ plan: WorkoutPlan)    { workoutPlans.append(plan) }
    func updatePlan(_ plan: WorkoutPlan) {
        if let i = workoutPlans.firstIndex(where: { $0.id == plan.id }) { workoutPlans[i] = plan }
    }
    func deletePlan(_ plan: WorkoutPlan) { workoutPlans.removeAll { $0.id == plan.id } }

    private func savePlans() {
        if let data = try? JSONEncoder().encode(workoutPlans) {
            UserDefaults.standard.set(data, forKey: Self.plansKey)
        }
    }

    private func loadPlans() {
        if let data = UserDefaults.standard.data(forKey: Self.plansKey),
           let saved = try? JSONDecoder().decode([WorkoutPlan].self, from: data) {
            workoutPlans = saved
        }
    }

    // MARK: - Body management

    private static let bodyDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    private func bodyDateKey(for date: Date) -> String {
        Self.bodyDateFormatter.string(from: date)
    }

    var dietStatusByDate: [String: String] = {
        if let data = UserDefaults.standard.data(forKey: AppState.dietStatusLogsKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            return decoded
        }
        return [:]
    }() {
        didSet {
            if let data = try? JSONEncoder().encode(dietStatusByDate) {
                UserDefaults.standard.set(data, forKey: Self.dietStatusLogsKey)
            }
        }
    }

    var weightLogs: [WeightLogEntry] = {
        if let data = UserDefaults.standard.data(forKey: AppState.weightLogsKey),
           let decoded = try? JSONDecoder().decode([WeightLogEntry].self, from: data) {
            return decoded.sorted(by: { $0.date < $1.date })
        }
        return []
    }() {
        didSet {
            if let data = try? JSONEncoder().encode(weightLogs) {
                UserDefaults.standard.set(data, forKey: Self.weightLogsKey)
            }
        }
    }

    var todayDietStatus: DietStatus? {
        guard let raw = dietStatusByDate[bodyDateKey(for: .now)] else { return nil }
        return DietStatus(rawValue: raw)
    }

    func setTodayDietStatus(_ status: DietStatus) {
        dietStatusByDate[bodyDateKey(for: .now)] = status.rawValue
    }

    func addWeightLogToday(_ weightKg: Double) {
        let normalized = max(20, min(weightKg, 300))
        let today = Calendar.current.startOfDay(for: .now)
        if let idx = weightLogs.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            weightLogs[idx].weightKg = normalized
            weightLogs[idx].date = today
        } else {
            weightLogs.append(WeightLogEntry(date: today, weightKg: normalized))
        }
        weightLogs.sort(by: { $0.date < $1.date })
    }

    init() {
        loadExercises()
        loadPlans()
        normalizePlantSelectionState()
    }

    private func normalizePlantSelectionState() {
        if !hasSelectedPlant {
            // First launch: explicitly keep "no pot selected" state.
            selectedPlantID = 0
            plantHydration = 0
            mustSwitchPot = false
            return
        }

        // Existing users: keep data, but repair invalid ID if needed.
        if !plantCatalog.contains(where: { $0.id == selectedPlantID }) {
            selectedPlantID = plantCatalog.first?.id ?? 1
        }
    }

    let plantCatalog: [PlantCatalogEntry] = [
        .init(id: 1, name: "富貴樹", englishName: "Wealth tree",
              quote: "代表著高貴奢華，同時也代表著力量。", unlockTarget: 5,
              imagePath: "drawable/plant_1", lockImagePath: "drawable/plant_1_lock"),
        .init(id: 2, name: "幸運の花", englishName: "Lucky flower",
              quote: "繁華的秋日，捎來盛開的好運。", unlockTarget: 5,
              imagePath: "drawable/plant_2", lockImagePath: "drawable/plant_2_lock"),
        .init(id: 3, name: "龜背芋", englishName: "Monstera deliciosa",
              quote: "具有強大的生命力和長壽。", unlockTarget: 5,
              imagePath: "drawable/plant_3", lockImagePath: "drawable/plant_3_lock"),
        .init(id: 4, name: "波斯頓厥", englishName: "Boston Fern",
              quote: "克服挑戰並取得勝利。", unlockTarget: 5,
              imagePath: "drawable/plant_4", lockImagePath: "drawable/plant_4_lock"),
        .init(id: 5, name: "常春藤", englishName: "Hedera helix",
              quote: "打造全新的開始，活出真正的自我。", unlockTarget: 5,
              imagePath: "drawable/plant_5", lockImagePath: "drawable/plant_5_lock"),
        .init(id: 6, name: "蘆薈", englishName: "Aloe vera",
              quote: "從痛苦創傷中復原，並帶給人能量。", unlockTarget: 5,
              imagePath: "drawable/plant_6", lockImagePath: "drawable/plant_6_lock"),
        .init(id: 7, name: "刺刺", englishName: "Thorn thorn",
              quote: "不論要等待多久，我都不會放棄。", unlockTarget: 5,
              imagePath: "drawable/plant_7", lockImagePath: "drawable/plant_7_lock"),
        .init(id: 8, name: "變葉木", englishName: "Codiaeum variegatum",
              quote: "專注守候，真心地奉獻。", unlockTarget: 5,
              imagePath: "drawable/plant_8", lockImagePath: "drawable/plant_8_lock"),
        .init(id: 9, name: "牽牛花", englishName: "Ipomoea nil",
              quote: "不輕易消失的美麗。", unlockTarget: 10,
              imagePath: "drawable/plant_9", lockImagePath: "drawable/plant_9_lock"),
        .init(id: 10, name: "含苞待放", englishName: "In early puberty",
              quote: "寂靜的藍調，擁抱悲傷的靈魂。", unlockTarget: 10,
              imagePath: "drawable/plant_10", lockImagePath: "drawable/plant_10_lock"),
        .init(id: 11, name: "叮叮噹", englishName: "Ding dong",
              quote: "將對你的思念，化成我唯一的花與葉。", unlockTarget: 10,
              imagePath: "drawable/plant_11", lockImagePath: "drawable/plant_11_lock"),
        .init(id: 12, name: "薄荷草", englishName: "Mentha haplocalyx",
              quote: "不起眼的外型，卻有濃郁沁人的清香。", unlockTarget: 10,
              imagePath: "drawable/plant_12", lockImagePath: "drawable/plant_12_lock"),
        .init(id: 13, name: "招財樹", englishName: "Malabar chestnut",
              quote: "堅韌而沉著，好運和財富的代表", unlockTarget: 10,
              imagePath: "drawable/plant_13", lockImagePath: "drawable/plant_13_lock"),
        .init(id: 14, name: "幸福木", englishName: "Radermachera sinica",
              quote: "和諧之美，平衡之美，純真快樂。", unlockTarget: 10,
              imagePath: "drawable/plant_14", lockImagePath: "drawable/plant_14_lock"),
        .init(id: 15, name: "可樂草", englishName: "Cola tree",
              quote: "紀念回憶，代表著擦去回憶的憂傷。", unlockTarget: 10,
              imagePath: "drawable/plant_15", lockImagePath: "drawable/plant_15_lock"),
        .init(id: 16, name: "一支獨秀", englishName: "A single show",
              quote: "與春共舞，欣欣向榮。", unlockTarget: 10,
              imagePath: "drawable/plant_16", lockImagePath: "drawable/plant_16_lock"),
        .init(id: 17, name: "小白花", englishName: "White flower",
              quote: "高貴而純潔的意志。", unlockTarget: 10,
              imagePath: "drawable/plant_17", lockImagePath: "drawable/plant_17_lock"),
        .init(id: 18, name: "夏威夷", englishName: "Hawaii",
              quote: "吹拂著微風，哼唱著夏天的歌。", unlockTarget: 10,
              imagePath: "drawable/plant_18", lockImagePath: "drawable/plant_18_lock"),
        .init(id: 19, name: "串串", englishName: "String String",
              quote: "突破限制，屹立不搖的毅力與耐力。", unlockTarget: 10,
              imagePath: "drawable/plant_19", lockImagePath: "drawable/plant_19_lock"),
        .init(id: 20, name: "三葉草", englishName: "Shamrock",
              quote: "今生唯有你，才會如此幸運。", unlockTarget: 10,
              imagePath: "drawable/plant_20", lockImagePath: "drawable/plant_20_lock"),
        .init(id: 21, name: "蘆薈", englishName: "Aloe vera",
              quote: "從痛苦創傷中復原，並帶給人能量。", unlockTarget: 20,
              imagePath: "drawable/plant_21", lockImagePath: "drawable/plant_21_lock"),
        .init(id: 22, name: "鏡面草", englishName: "Pilea peperomioides",
              quote: "閃閃發光，為你的生活帶來亮眼曙光。", unlockTarget: 20,
              imagePath: "drawable/plant_22", lockImagePath: "drawable/plant_22_lock"),
        .init(id: 23, name: "百合", englishName: "Lilium",
              quote: "深谷裡堅毅的笑容，在低潮時不忘抬頭。", unlockTarget: 20,
              imagePath: "drawable/plant_23", lockImagePath: "drawable/plant_23_lock"),
        .init(id: 24, name: "火鶴花", englishName: "Anthurium andraeanum",
              quote: "永恆的愛和純真的心靈。", unlockTarget: 20,
              imagePath: "drawable/plant_24", lockImagePath: "drawable/plant_24_lock"),
        .init(id: 25, name: "蔓綠絨", englishName: "Philodendron",
              quote: "熱情似火，如果實般紅艷。", unlockTarget: 20,
              imagePath: "drawable/plant_25", lockImagePath: "drawable/plant_25_lock"),
        .init(id: 26, name: "胖胖仙子", englishName: "Chubby fairy",
              quote: "在我面前不用裝堅強，外型可愛討喜。", unlockTarget: 20,
              imagePath: "drawable/plant_26", lockImagePath: "drawable/plant_26_lock"),
        .init(id: 27, name: "鋼鐵仙人掌", englishName: "Steel Cactus",
              quote: "在荒蕪之中，依然倔強地綻放。", unlockTarget: 100,
              imagePath: "drawable/plant_27", lockImagePath: "drawable/plant_27_lock"),
        .init(id: 28, name: "虎尾蘭", englishName: "Snake plant",
              quote: "不張揚的溫柔，剛剛好治癒人心。", unlockTarget: 200,
              imagePath: "drawable/plant_28", lockImagePath: "drawable/plant_28_lock"),
    ]

    // MARK: - Navigation

    var screen: AppScreen = .home
    var workoutPhase: WorkoutPhase = .training
    var homeTab: HomeTab = .tree
    var showGlobalMenu: Bool = false

    // MARK: - Persistent plant data (UserDefaults-backed)

    var selectedPlantID: Int = {
        if let stored = UserDefaults.standard.object(forKey: "selectedPlantID") as? Int {
            return stored
        }
        return 0
    }() { didSet { UserDefaults.standard.set(selectedPlantID, forKey: "selectedPlantID") } }

    /// 使用者是否已經主動選過盆栽（未選時禁止開始運動）
    var hasSelectedPlant: Bool = UserDefaults.standard.bool(forKey: "hasSelectedPlant") {
        didSet { UserDefaults.standard.set(hasSelectedPlant, forKey: "hasSelectedPlant") }
    }

    /// 目前盆栽澆水進度（0~100）
    var plantHydration: Double = {
        (UserDefaults.standard.object(forKey: "plantHydration") as? Double) ?? 0
    }() { didSet { UserDefaults.standard.set(plantHydration, forKey: "plantHydration") } }

    /// 目前是否達 100% 並等待換盆（此時禁止運動）
    var mustSwitchPot: Bool = UserDefaults.standard.bool(forKey: "mustSwitchPot") {
        didSet { UserDefaults.standard.set(mustSwitchPot, forKey: "mustSwitchPot") }
    }

    /// 每個盆栽完成次數（花園 x?）
    var plantCompletionCounts: [Int: Int] = {
        if let data = UserDefaults.standard.data(forKey: "plantCompletionCounts"),
           let decoded = try? JSONDecoder().decode([Int: Int].self, from: data) {
            return decoded
        }
        return [:]
    }() {
        didSet {
            if let data = try? JSONEncoder().encode(plantCompletionCounts) {
                UserDefaults.standard.set(data, forKey: "plantCompletionCounts")
            }
        }
    }

    /// 種植完成紀錄（歷史）
    var plantingRecords: [PlantingRecord] = {
        if let data = UserDefaults.standard.data(forKey: "plantingRecords"),
           let decoded = try? JSONDecoder().decode([PlantingRecord].self, from: data) {
            return decoded
        }
        return []
    }() {
        didSet {
            if let data = try? JSONEncoder().encode(plantingRecords) {
                UserDefaults.standard.set(data, forKey: "plantingRecords")
            }
        }
    }

    /// 最近一次完成盆栽後得到的獎勵描述
    var lastPotRewardMessage: String = UserDefaults.standard.string(forKey: "lastPotRewardMessage") ?? "" {
        didSet { UserDefaults.standard.set(lastPotRewardMessage, forKey: "lastPotRewardMessage") }
    }

    /// 100% 完成後提示使用者換盆
    var showSwitchPotPrompt: Bool = false
    var switchPotPromptMessage: String = ""

    var totalSetsCompleted: Int = {
        UserDefaults.standard.integer(forKey: "totalSetsCompleted")
    }() { didSet { UserDefaults.standard.set(totalSetsCompleted, forKey: "totalSetsCompleted") } }

    var lastWorkoutTimestamp: Double = UserDefaults.standard.double(forKey: "lastWorkoutTimestamp") {
        didSet { UserDefaults.standard.set(lastWorkoutTimestamp, forKey: "lastWorkoutTimestamp") }
    }

    /// 今日消耗熱量（kcal），每次 finishAndGoHome 累加，當天重置
    var todayCalories: Double = {
        let ts = UserDefaults.standard.double(forKey: "todayCaloriesDate")
        guard ts > 0, Calendar.current.isDateInToday(Date(timeIntervalSince1970: ts)) else { return 0 }
        return (UserDefaults.standard.object(forKey: "todayCalories") as? Double) ?? 0
    }() {
        didSet {
            UserDefaults.standard.set(todayCalories, forKey: "todayCalories")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "todayCaloriesDate")
        }
    }


    /// 累積總消耗熱量（長期）
    var lifetimeCalories: Double = {
        (UserDefaults.standard.object(forKey: "lifetimeCalories") as? Double) ?? 0
    }() { didSet { UserDefaults.standard.set(lifetimeCalories, forKey: "lifetimeCalories") } }

    /// 今日完成動作數，每天重置
    var todaySets: Int = {
        let ts = UserDefaults.standard.double(forKey: "todaySetsDate")
        guard ts > 0, Calendar.current.isDateInToday(Date(timeIntervalSince1970: ts)) else { return 0 }
        return UserDefaults.standard.integer(forKey: "todaySets")
    }() {
        didSet {
            UserDefaults.standard.set(todaySets, forKey: "todaySets")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "todaySetsDate")
        }
    }

    /// HealthKit 今日步數
    var todayStepCount: Int = 0

    /// HealthKit 今日運動紀錄數（跑步/球類等 workout）
    var todayHealthWorkoutCount: Int = 0

    /// 步數換算熱量（粗估）：每步約 0.04 kcal
    var todayStepCalories: Double {
        Double(todayStepCount) * 0.04
    }

    /// 今日總消耗（訓練 + 步數）
    var todayTotalCalories: Double {
        todayCalories + todayStepCalories
    }

    /// 連續訓練天數
    var workoutStreak: Int = {
        UserDefaults.standard.integer(forKey: "workoutStreak")
    }() { didSet { UserDefaults.standard.set(workoutStreak, forKey: "workoutStreak") } }

    private var lastStreakTimestamp: Double = UserDefaults.standard.double(forKey: "lastStreakTimestamp") {
        didSet { UserDefaults.standard.set(lastStreakTimestamp, forKey: "lastStreakTimestamp") }
    }

    var lastExerciseName: String = UserDefaults.standard.string(forKey: "lastExerciseName") ?? "" {
        didSet { UserDefaults.standard.set(lastExerciseName, forKey: "lastExerciseName") }
    }

    var lastWeight: Double = {
        (UserDefaults.standard.object(forKey: "lastWeight") as? Double) ?? 0
    }() { didSet { UserDefaults.standard.set(lastWeight, forKey: "lastWeight") } }

    var lastReps: Int = {
        let v = UserDefaults.standard.integer(forKey: "lastReps")
        return v == 0 ? 10 : v
    }() { didSet { UserDefaults.standard.set(lastReps, forKey: "lastReps") } }

    var weightUnitRaw: String = {
        UserDefaults.standard.string(forKey: "weightUnitRaw") ?? WeightUnit.kg.rawValue
    }() { didSet { UserDefaults.standard.set(weightUnitRaw, forKey: "weightUnitRaw") } }

    // MARK: - Active workout session

    var selectedExercise: Exercise?
    var currentSet: Int = 1
    var totalSets: Int = 4
    var currentSetStartTime: Date = .now
    var weightKg: Double = 0
    var editingWeight: Bool = false
    var weightInputText: String = ""
    var selectedReps: Int = 10
    var remainingRestSeconds: Int = 0
    private var restStartDate: Date? = nil
    private var restTotalSeconds: Int = 0
    private var liveActivityID: String? = nil
    var setRecords: [SetRecord] = []
    var pendingWaterGain: Double = 0

    // MARK: - Animation flags

    var plantScale: Double = 1.0
    var waterDropVisible: Bool = false
    var showSummaryWater: Bool = false

    // MARK: - Computed helpers

    var currentPlant: PlantCatalogEntry {
        if !hasSelectedPlant { return .unselected }
        return plantCatalog.first(where: { $0.id == selectedPlantID })
            ?? plantCatalog.first
            ?? .fallback
    }

    var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
        set { weightUnitRaw = newValue.rawValue }
    }

    func weightValue(fromKg kg: Double) -> Double {
        switch weightUnit {
        case .kg: return kg
        case .lb: return kg * 2.2046226218
        }
    }

    func kg(fromWeightValue value: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kg: return value
        case .lb: return value / 2.2046226218
        }
    }

    func weightText(fromKg kg: Double) -> String {
        let v = weightValue(fromKg: kg)
        let rounded = (v.rounded(.down) == v) ? String(Int(v)) : String(format: "%.1f", v)
        return "\(rounded) \(weightUnit == .kg ? "kg" : "lb")"
    }
    
    func plantCount(for plantID: Int) -> Int {
        plantCompletionCounts[plantID] ?? 0
    }

    var totalPlantCompletions: Int {
        plantCompletionCounts.values.reduce(0, +)
    }

    var uniquePlantsCompletedCount: Int {
        plantCompletionCounts.filter { $0.value > 0 }.count
    }

    // MARK: - Achievements (rich + point system)

    private static let achievementDefs: [AchievementDefinition] = [
        .init(id: "a_first_action", title: "第一步", subtitle: "完成 1 次動作", icon: "figure.walk", metric: .totalActions, target: 1, points: 1),
        .init(id: "a_action_10", title: "動作新手", subtitle: "累積完成 10 次動作", icon: "figure.strengthtraining.traditional", metric: .totalActions, target: 10, points: 2),
        .init(id: "a_action_50", title: "訓練節奏", subtitle: "累積完成 50 次動作", icon: "bolt.heart.fill", metric: .totalActions, target: 50, points: 4),
        .init(id: "a_action_120", title: "穩定輸出", subtitle: "累積完成 120 次動作", icon: "flame.fill", metric: .totalActions, target: 120, points: 6),
        .init(id: "a_streak_3", title: "連續出勤", subtitle: "連續訓練 3 天", icon: "calendar.badge.clock", metric: .workoutStreak, target: 3, points: 2),
        .init(id: "a_streak_7", title: "不間斷", subtitle: "連續訓練 7 天", icon: "calendar.badge.checkmark", metric: .workoutStreak, target: 7, points: 4),
        .init(id: "a_today_300", title: "今日燃燒", subtitle: "今日消耗 300 kcal", icon: "flame.circle.fill", metric: .todayCalories, target: 300, points: 2),
        .init(id: "a_lifetime_3000", title: "熱量引擎", subtitle: "累積消耗 3000 kcal", icon: "gauge.with.needle.fill", metric: .lifetimeCalories, target: 3000, points: 5),
        .init(id: "a_plant_3", title: "園藝入門", subtitle: "完成 3 次種植", icon: "leaf.fill", metric: .totalPlantCompletions, target: 3, points: 3),
        .init(id: "a_plant_10", title: "綠手指", subtitle: "完成 10 次種植", icon: "tree.fill", metric: .totalPlantCompletions, target: 10, points: 6),
        .init(id: "a_variety_3", title: "多樣栽培", subtitle: "完成 3 種不同盆栽", icon: "sparkles", metric: .uniquePlantsCompleted, target: 3, points: 3),
        .init(id: "a_plan_2", title: "菜單管理者", subtitle: "建立 2 份訓練菜單", icon: "list.bullet.rectangle.portrait", metric: .totalPlans, target: 2, points: 2),
        .init(id: "a_custom_5", title: "動作設計師", subtitle: "新增 5 個自訂動作", icon: "pencil.and.list.clipboard", metric: .customExercises, target: 5, points: 3)
    ]

    private func metricValue(_ metric: AchievementMetric) -> Int {
        switch metric {
        case .totalActions: return totalSetsCompleted
        case .workoutStreak: return workoutStreak
        case .todayCalories: return Int(todayTotalCalories)
        case .lifetimeCalories: return Int(lifetimeCalories)
        case .totalPlantCompletions: return totalPlantCompletions
        case .uniquePlantsCompleted: return uniquePlantsCompletedCount
        case .totalPlans: return workoutPlans.count
        case .customExercises: return max(0, exercises.count - Self.defaultExercises.count)
        }
    }

    var achievementProgressItems: [AchievementProgressItem] {
        Self.achievementDefs.map { def in
            let current = metricValue(def.metric)
            return AchievementProgressItem(definition: def, current: current, isUnlocked: current >= def.target)
        }
    }

    var unlockedAchievementCount: Int {
        achievementProgressItems.filter(\.isUnlocked).count
    }

    var achievementPoints: Int {
        achievementProgressItems.filter(\.isUnlocked).reduce(0) { $0 + $1.definition.points }
    }

    /// 花盆解鎖改為「成就積分」
    func unlockRequirement(for plantID: Int) -> Int {
        let table: [Int] = [
            0, 0, 2, 4, 6, 8, 10, 12, 14, 16,
            18, 20, 23, 26, 29, 32, 35, 39, 43, 47,
            51, 56, 61, 66, 72, 78
        ]
        let idx = max(0, min(plantID - 1, table.count - 1))
        return table[idx]
    }

    func isPlantUnlocked(_ plantID: Int) -> Bool {
        achievementPoints >= unlockRequirement(for: plantID)
    }

    var unlockedPlantCount: Int {
        plantCatalog.filter { isPlantUnlocked($0.id) }.count
    }

    func nextLockedPlant() -> PlantCatalogEntry? {
        plantCatalog.first { !isPlantUnlocked($0.id) }
    }

    func additionalPointsToUnlock(_ plant: PlantCatalogEntry) -> Int {
        max(0, unlockRequirement(for: plant.id) - achievementPoints)
    }

    func unlockablePlants(withAdditionalPoints extraPoints: Int) -> [PlantCatalogEntry] {
        let current = achievementPoints
        let future = current + max(0, extraPoints)
        return plantCatalog.filter { plant in
            let req = unlockRequirement(for: plant.id)
            return req > current && req <= future
        }
    }

    /// 每個盆栽各自不同的澆水目標（完成幾次動作到 100%）
    func wateringGoalSets(for plantID: Int) -> Int {
        // 依照 catalog 基礎目標再加偏移，避免大量重複
        let base = plantCatalog.first(where: { $0.id == plantID })?.unlockTarget ?? 8
        let offset = (plantID % 4) // 0~3
        return max(4, base + offset)
    }

    var canStartWorkout: Bool {
        hasSelectedPlant && !mustSwitchPot
    }

    var quickStartExercise: Exercise? {
        if lastExerciseName.isEmpty { return exercises.first }
        return exercises.first(where: { $0.name == lastExerciseName }) ?? exercises.first
    }

    var hasWorkoutToday: Bool {
        guard lastWorkoutTimestamp > 0 else { return false }
        return Calendar.current.isDateInToday(Date(timeIntervalSince1970: lastWorkoutTimestamp))
    }

    /// 今日運動次數（App 內動作 + HealthKit workout）
    var todayActivityCount: Int {
        todaySets + todayHealthWorkoutCount
    }

    var ringProgress: CGFloat {
        CGFloat(min(max(plantHydration / 100.0, 0), 1))
    }

    var hydrationLevel: Int {
        let goal = wateringGoalSets(for: selectedPlantID)
        let step = 100.0 / Double(max(goal, 1))
        return min(max(Int(ceil(plantHydration / step)), 0), goal)
    }

    var plantHealth: Double {
        if hasWorkoutToday { return 1 }
        guard lastWorkoutTimestamp > 0 else { return 0 }
        let date = Date(timeIntervalSince1970: lastWorkoutTimestamp)
        let today = Calendar.current.startOfDay(for: .now)
        let last  = Calendar.current.startOfDay(for: date)
        let days  = Calendar.current.dateComponents([.day], from: last, to: today).day ?? 7
        return min(max(1 - Double(days) / 5.0, 0), 1)
    }

    var plantColor: Color {
        Color.blended(from: .systemYellow, to: .systemGreen, amount: plantHealth)
    }

    // MARK: - HealthKit

    func requestHealthKitAccessIfNeeded() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard Bundle.main.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") != nil else { return }
        guard !healthKitRequested else {
            refreshHealthKitTodayStatsIfNeeded(force: true)
            return
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let workoutType = HKObjectType.workoutType()
        let readTypes: Set<HKObjectType> = [stepType, workoutType]

        healthStore.requestAuthorization(toShare: [], read: readTypes) { [weak self] success, _ in
            guard let self else { return }
            self.healthKitRequested = true
            if success {
                DispatchQueue.main.async {
                    self.refreshHealthKitTodayStatsIfNeeded(force: true)
                }
            }
        }
    }

    func refreshHealthKitTodayStatsIfNeeded(force: Bool = false) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        if !force, Date().timeIntervalSince(lastHealthKitRefreshAt) < 60 { return }
        lastHealthKitRefreshAt = Date()
        refreshTodayStepCount()
        refreshTodayWorkoutCount()
    }

    private func refreshTodayStepCount() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: .now),
            end: Date(),
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            guard let self else { return }
            let count = Int(result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
            DispatchQueue.main.async {
                self.todayStepCount = max(0, count)
            }
        }
        healthStore.execute(query)
    }

    private func refreshTodayWorkoutCount() {
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: .now),
            end: Date(),
            options: .strictStartDate
        )

        let query = HKSampleQuery(
            sampleType: .workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { [weak self] _, samples, _ in
            guard let self else { return }
            let count = samples?.count ?? 0
            DispatchQueue.main.async {
                self.todayHealthWorkoutCount = max(0, count)
            }
        }
        healthStore.execute(query)
    }

    // MARK: - Actions

    func startExercise(
        _ exercise: Exercise,
        totalSetsOverride: Int? = nil,
        weightKgOverride: Double? = nil,
        repsOverride: Int? = nil
    ) {
        // 未選盆栽或已達 100% 必須換盆時，不可開始運動
        guard hasSelectedPlant else {
            switchPotPromptMessage = "請先到花園選擇要栽培的盆栽，才能開始運動。"
            showSwitchPotPrompt = true
            homeTab = .garden
            screen = .home
            return
        }
        guard !mustSwitchPot else {
            switchPotPromptMessage = "當前盆栽已達 100%，請先到花園選擇其他花盆後再開始運動。"
            showSwitchPotPrompt = true
            homeTab = .garden
            screen = .home
            return
        }

        selectedExercise = exercise
        currentSet       = 1
        totalSets        = max(1, totalSetsOverride ?? exercise.defaultSets)
        if let weightKgOverride {
            weightKg = max(0, weightKgOverride)
        } else {
            weightKg = (lastExerciseName == exercise.name) ? lastWeight : max(0, exercise.defaultWeightKg)
        }
        if let repsOverride {
            selectedReps = max(1, repsOverride)
        } else {
            selectedReps = lastReps
        }
        setRecords         = []
        pendingWaterGain   = 0
        currentSetStartTime = .now
        workoutPhase       = .training
        showSummaryWater   = false
        waterDropVisible   = false
        screen             = .workout
    }

    func tapDone() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        // Use the planned reps (`selectedReps`) directly and continue the flow.
        confirmReps()
    }

    func confirmReps() {
        guard let exercise = selectedExercise else { return }

        setRecords.append(SetRecord(setNumber: currentSet, reps: selectedReps, weight: weightKg, startedAt: currentSetStartTime))
        // 澆水改為「整個動作完成一次」才計算（不是每組）

        lastExerciseName    = exercise.name
        lastWeight          = weightKg
        lastReps            = selectedReps
        lastWorkoutTimestamp = Date().timeIntervalSince1970

        // 若本次訓練有設定重量，回寫成該動作的預設重量
        // 之後再次開始同動作時會直接帶入。
        if weightKg > 0,
           let idx = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[idx].defaultWeightKg = weightKg
            selectedExercise?.defaultWeightKg = weightKg
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if currentSet >= totalSets {
            // 一個動作完成（例如 5 組）才算 1 次
            totalSetsCompleted += 1

            // 一個動作完成才算 1 次澆水進度
            let goalActions = Double(wateringGoalSets(for: selectedPlantID))
            pendingWaterGain = (100.0 / max(goalActions, 1.0))

            triggerWaterDropAnimation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { self.workoutPhase = .summary }
        } else {
            currentSet += 1
            restTotalSeconds = exercise.restSeconds
            remainingRestSeconds = exercise.restSeconds
            let start = Date()
            restStartDate = start
            workoutPhase = .resting
            triggerWaterDropAnimation()
            startRestLiveActivity(
                exerciseName: exercise.name,
                totalSeconds: exercise.restSeconds,
                endDate: start.addingTimeInterval(TimeInterval(exercise.restSeconds)),
                currentSet: currentSet,
                totalSets: totalSets
            )
        }
    }

    func triggerWaterDropAnimation() {
        withAnimation(.spring(duration: 0.3)) { waterDropVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeOut(duration: 0.3)) { self.waterDropVisible = false }
        }
    }

    func handleCountdownTick() {
        tickHealthKitMinuteRefresh()

        guard workoutPhase == .resting else { return }
        if let start = restStartDate {
            let elapsed = Int(Date().timeIntervalSince(start))
            remainingRestSeconds = max(0, restTotalSeconds - elapsed)
        } else {
            remainingRestSeconds = max(0, remainingRestSeconds - 1)
        }
        if remainingRestSeconds == 0 { endRest() }
    }

    /// 依目前 SwiftData 的訓練紀錄重算首頁統計（刪除紀錄後使用）
    func refreshSummaryStats(from sessions: [WorkoutSession]) {
        let cal = Calendar.current
        let todaySessions = sessions.filter { cal.isDateInToday($0.date) }

        let todayCaloriesValue = todaySessions.reduce(0.0) { total, session in
            total + session.sets.reduce(0.0) { $0 + Double($1.reps) * $1.weightKg * 0.08 }
        }
        let lifetimeCaloriesValue = sessions.reduce(0.0) { total, session in
            total + session.sets.reduce(0.0) { $0 + Double($1.reps) * $1.weightKg * 0.08 }
        }

        todayCalories = todayCaloriesValue
        todaySets = todaySessions.count
        lifetimeCalories = lifetimeCaloriesValue
    }

    private func tickHealthKitMinuteRefresh() {
        let minuteStamp = Int(Date().timeIntervalSince1970 / 60)
        guard minuteStamp != lastHealthKitMinuteStamp else { return }
        lastHealthKitMinuteStamp = minuteStamp
        refreshHealthKitTodayStatsIfNeeded(force: false)
    }

    func endRest() {
        restStartDate = nil
        endRestLiveActivity()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        currentSetStartTime = .now
        workoutPhase = .training
    }

    func skipRest() {
        remainingRestSeconds = 0
        restStartDate = nil
        endRestLiveActivity()
        endRest()
    }

    // MARK: - Live Activity helpers

    private func startRestLiveActivity(exerciseName: String, totalSeconds: Int, endDate: Date, currentSet: Int, totalSets: Int) {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = RestTimerAttributes.ContentState(
            endDate: endDate,
            totalSeconds: totalSeconds,
            exerciseName: exerciseName,
            currentSet: currentSet,
            totalSets: totalSets
        )
        let content = ActivityContent(state: state, staleDate: endDate)
        let activity = try? Activity.request(
            attributes: RestTimerAttributes(),
            content: content,
            pushType: nil
        )
        liveActivityID = activity?.id
    }

    private func endRestLiveActivity() {
        guard #available(iOS 16.2, *) else { return }
        guard let id = liveActivityID else { return }
        Task {
            for activity in Activity<RestTimerAttributes>.activities where activity.id == id {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        liveActivityID = nil
    }

    func finishExercise() { showSummaryWater = false; workoutPhase = .summary }

    func finishAndGoHome(modelContext: ModelContext? = nil) {
        // 儲存本次訓練到 SwiftData
        if let ctx = modelContext, let exercise = selectedExercise, !setRecords.isEmpty {
            let session = WorkoutSession(
                exerciseName: exercise.name,
                muscleGroup: exercise.muscleGroup,
                date: .now,
                totalSets: setRecords.count
            )
            ctx.insert(session)
            for record in setRecords {
                let set = WorkoutSet(
                    setNumber: record.setNumber,
                    reps: record.reps,
                    weightKg: record.weight
                )
                set.session = session
                ctx.insert(set)
            }
            try? ctx.save()
        }

        // 計算本次消耗熱量（粗略：reps × weight × 0.08）
        let sessionCalories = setRecords.reduce(0.0) { $0 + Double($1.reps) * $1.weight * 0.08 }
        todayCalories += sessionCalories
        lifetimeCalories += sessionCalories
        todaySets += 1

        // 更新連續天數
        updateStreak()

        plantHydration = min(plantHydration + pendingWaterGain, 100)
        finalizePotIfNeeded()

        withAnimation(.spring(duration: 0.6)) { plantScale = 1.10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(duration: 0.4)) { self.plantScale = 1.0 }
        }
        resetSession()
        screen = .home
    }

    private func updateStreak() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        if lastStreakTimestamp > 0 {
            let lastDay = cal.startOfDay(for: Date(timeIntervalSince1970: lastStreakTimestamp))
            let diff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 0 {
                // 同一天多次訓練不重複累加
            } else if diff == 1 {
                workoutStreak += 1
            } else {
                workoutStreak = 1
            }
        } else {
            workoutStreak = 1
        }
        lastStreakTimestamp = Date().timeIntervalSince1970
        lastWorkoutTimestamp = Date().timeIntervalSince1970
    }

    private func applyPotCompletionReward(for plantID: Int) {
        // 簡化版：依 plantID 分配不同獎勵類型
        switch plantID % 4 {
        case 0:
            let bonus = max(20, todayCalories * 0.08)
            todayCalories += bonus
            lastPotRewardMessage = "獎勵：熱量加成 +\(Int(bonus)) kcal"
        case 1:
            todaySets += 2
            lastPotRewardMessage = "獎勵：額外 +2 組計入今日成就"
        case 2:
            let bonus = 30.0
            todayCalories += bonus
            lastPotRewardMessage = "獎勵：額外 +\(Int(bonus)) kcal"
        default:
            workoutStreak += 1
            lastPotRewardMessage = "獎勵：連續天數 +1"
        }
    }

    private func finalizePotIfNeeded() {
        if plantHydration >= 100 {
            plantHydration = 100
            mustSwitchPot = true
            plantCompletionCounts[selectedPlantID, default: 0] += 1
            applyPotCompletionReward(for: selectedPlantID)

            let record = PlantingRecord(
                plantID: selectedPlantID,
                plantName: currentPlant.name,
                completedAt: .now,
                rewardMessage: lastPotRewardMessage
            )
            plantingRecords.insert(record, at: 0)

            // 100% 後強制導向花園選新盆栽
            switchPotPromptMessage = "\(currentPlant.name) 已達 100%。請選擇其他花盆繼續栽培。"
            showSwitchPotPrompt = true
            homeTab = .garden
        }
    }


    func canChoosePlant(_ plant: PlantCatalogEntry) -> Bool {
        isPlantUnlocked(plant.id)
    }

    func plantSelectHint(for plant: PlantCatalogEntry) -> String {
        if !isPlantUnlocked(plant.id) {
            return "尚未解鎖：需成就積分 \(unlockRequirement(for: plant.id))（目前 \(achievementPoints)）"
        }
        if !hasSelectedPlant {
            return "請選擇你今天要栽培的盆栽"
        }
        if hasSelectedPlant, selectedPlantID != plant.id, plantHydration > 0 {
            return "切換後會清空目前澆水進度"
        }
        return "可開始栽培"
    }

    @discardableResult
    func choosePlant(_ plant: PlantCatalogEntry) -> Bool {
        if !isPlantUnlocked(plant.id) { return false }

        let shouldResetHydration = !hasSelectedPlant || selectedPlantID != plant.id

        hasSelectedPlant = true
        selectedPlantID = plant.id
        if shouldResetHydration {
            // 允許隨時換盆，若有進度則切換時清空
            plantHydration = 0
        }
        mustSwitchPot = false
        showSwitchPotPrompt = false
        switchPotPromptMessage = ""
        withAnimation(.easeInOut(duration: 0.35)) {
            homeTab = .tree
        }
        return true
    }

    // Legacy signature compatibility
    func choosePlantLegacy(_ plant: PlantCatalogEntry) {
        _ = choosePlant(plant)
    }

    func resetSession() {
        selectedExercise  = nil
        currentSet        = 1
        remainingRestSeconds = 0
        workoutPhase      = .training
        setRecords        = []
        pendingWaterGain  = 0
        waterDropVisible  = false
        showSummaryWater  = false
    }
}
