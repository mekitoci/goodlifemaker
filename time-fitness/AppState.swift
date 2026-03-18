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
    private static let healthKitRequestedKey = "healthkit_requested_v1"
    private let healthStore = HKHealthStore()
    private var healthKitRequested: Bool = UserDefaults.standard.bool(forKey: AppState.healthKitRequestedKey) {
        didSet { UserDefaults.standard.set(healthKitRequested, forKey: AppState.healthKitRequestedKey) }
    }
    private var lastHealthKitRefreshAt: Date = .distantPast

    // MARK: - Exercise catalog（支援 CRUD，UserDefaults 持久化）

    private static let exercisesKey = "user_exercises_v1"

    private static let defaultExercises: [Exercise] = [
        .init(name: "槓鈴臥推",  muscleGroup: "胸",   defaultSets: 4, restSeconds: 90),
        .init(name: "啞鈴飛鳥",  muscleGroup: "胸",   defaultSets: 4, restSeconds: 90),
        .init(name: "引體向上",  muscleGroup: "背",   defaultSets: 4, restSeconds: 90),
        .init(name: "啞鈴划船",  muscleGroup: "背",   defaultSets: 4, restSeconds: 90),
        .init(name: "深蹲",     muscleGroup: "腿",   defaultSets: 4, restSeconds: 120),
        .init(name: "腿舉",     muscleGroup: "腿",   defaultSets: 4, restSeconds: 90),
        .init(name: "肩推",     muscleGroup: "肩",   defaultSets: 4, restSeconds: 90),
        .init(name: "二頭彎舉", muscleGroup: "手臂",  defaultSets: 3, restSeconds: 60),
        .init(name: "三頭下壓", muscleGroup: "手臂",  defaultSets: 3, restSeconds: 60),
    ]

    var exercises: [Exercise] = [] {
        didSet { saveExercises() }
    }

    private func loadExercises() {
        if let data = UserDefaults.standard.data(forKey: Self.exercisesKey),
           let saved = try? JSONDecoder().decode([Exercise].self, from: data) {
            exercises = saved
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
        exercises.append(exercise)
    }

    func updateExercise(_ exercise: Exercise) {
        if let idx = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[idx] = exercise
        }
    }

    func deleteExercise(_ exercise: Exercise) {
        exercises.removeAll { $0.id == exercise.id }
    }

    // MARK: - Workout Plans

    private static let plansKey = "user_workout_plans_v1"

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
            weightKg = first.targetWeightKg
            selectedReps = first.targetReps
            startExercise(ex)
        } else if let first = activePlanQueue.first {
            // exercise was deleted but plan item still has name - create a temp exercise
            let tempEx = Exercise(id: first.exerciseID, name: first.exerciseName,
                                  muscleGroup: first.muscleGroup, defaultSets: first.sets, restSeconds: 90)
            weightKg = first.targetWeightKg
            selectedReps = first.targetReps
            startExercise(tempEx)
        }
    }

    func advanceToNextPlanItem() {
        activePlanIndex += 1
        guard let next = activePlanItem else { return }
        let ex = exercises.first(where: { $0.id == next.exerciseID })
            ?? Exercise(id: next.exerciseID, name: next.exerciseName,
                        muscleGroup: next.muscleGroup, defaultSets: next.sets, restSeconds: 90)
        weightKg = next.targetWeightKg
        selectedReps = next.targetReps
        startExercise(ex)
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

    init() {
        loadExercises()
        loadPlans()
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
    ]

    // MARK: - Navigation

    var screen: AppScreen = .home
    var workoutPhase: WorkoutPhase = .training
    var homeTab: HomeTab = .tree
    var showGlobalMenu: Bool = false

    // MARK: - Persistent plant data (UserDefaults-backed)

    var selectedPlantID: Int = {
        let stored = UserDefaults.standard.integer(forKey: "selectedPlantID")
        return stored == 0 ? 1 : stored
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
        (UserDefaults.standard.object(forKey: "lastWeight") as? Double) ?? 60
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
    var weightKg: Double = 60
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
        plantCatalog.first(where: { $0.id == selectedPlantID })
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
        case .todayCalories: return Int(todayCalories)
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

    func startExercise(_ exercise: Exercise) {
        // 未選盆栽或已達 100% 必須換盆時，不可開始運動
        guard hasSelectedPlant else {
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
        totalSets        = exercise.defaultSets
        weightKg         = (lastExerciseName == exercise.name) ? lastWeight : 60
        selectedReps     = lastReps
        setRecords       = []
        pendingWaterGain = 0
        workoutPhase     = .training
        showSummaryWater = false
        waterDropVisible = false
        screen           = .workout
    }

    func tapDone() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        // Use the planned reps (`selectedReps`) directly and continue the flow.
        confirmReps()
    }

    func confirmReps() {
        guard let exercise = selectedExercise else { return }

        setRecords.append(SetRecord(setNumber: currentSet, reps: selectedReps, weight: weightKg))
        // 澆水改為「整個動作完成一次」才計算（不是每組）

        lastExerciseName    = exercise.name
        lastWeight          = weightKg
        lastReps            = selectedReps
        lastWorkoutTimestamp = Date().timeIntervalSince1970

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
        guard workoutPhase == .resting else { return }
        if let start = restStartDate {
            let elapsed = Int(Date().timeIntervalSince(start))
            remainingRestSeconds = max(0, restTotalSeconds - elapsed)
        } else {
            remainingRestSeconds = max(0, remainingRestSeconds - 1)
        }
        if remainingRestSeconds == 0 { endRest() }
    }

    func endRest() {
        restStartDate = nil
        endRestLiveActivity()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
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
        if !isPlantUnlocked(plant.id) { return false }
        if hasSelectedPlant, !mustSwitchPot, selectedPlantID != plant.id { return false }
        if mustSwitchPot, plant.id == selectedPlantID { return false }
        return true
    }

    func plantSelectHint(for plant: PlantCatalogEntry) -> String {
        if !isPlantUnlocked(plant.id) {
            return "尚未解鎖：需成就積分 \(unlockRequirement(for: plant.id))（目前 \(achievementPoints)）"
        }
        if !hasSelectedPlant { return "請選擇你今天要栽培的盆栽" }
        if mustSwitchPot, plant.id == selectedPlantID { return "此盆栽已完成，請改選其他盆栽" }
        if hasSelectedPlant, !mustSwitchPot, selectedPlantID != plant.id {
            return "目前盆栽尚未完成（100%），暫時不能切換"
        }
        return "可開始栽培"
    }

    @discardableResult
    func choosePlant(_ plant: PlantCatalogEntry) -> Bool {
        if !isPlantUnlocked(plant.id) { return false }
        // 尚未達 100% 前，不可切換到其他盆栽（第一盆例外）
        if hasSelectedPlant, !mustSwitchPot, selectedPlantID != plant.id {
            return false
        }
        // 若已達 100%，需切換到不同盆栽
        if mustSwitchPot, plant.id == selectedPlantID {
            return false
        }

        hasSelectedPlant = true
        selectedPlantID = plant.id
        plantHydration = 0
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
