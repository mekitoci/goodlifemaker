import SwiftUI
import UIKit
import Observation
import ActivityKit

// MARK: - AppState
// Single source of truth for the entire app.
// Injected as @Environment(AppState.self) from ContentView.

@Observable
final class AppState {

    // MARK: - Static catalog data

    let exercises: [Exercise] = [
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

    // MARK: - Persistent plant data (UserDefaults-backed)

    var selectedPlantID: Int = {
        let stored = UserDefaults.standard.integer(forKey: "selectedPlantID")
        return stored == 0 ? 1 : stored
    }() { didSet { UserDefaults.standard.set(selectedPlantID, forKey: "selectedPlantID") } }

    var plantHydration: Double = {
        (UserDefaults.standard.object(forKey: "plantHydration") as? Double) ?? 40
    }() { didSet { UserDefaults.standard.set(plantHydration, forKey: "plantHydration") } }

    var totalSetsCompleted: Int = {
        let v = UserDefaults.standard.integer(forKey: "totalSetsCompleted")
        return v == 0 ? 105 : v
    }() { didSet { UserDefaults.standard.set(totalSetsCompleted, forKey: "totalSetsCompleted") } }

    var lastWorkoutTimestamp: Double = UserDefaults.standard.double(forKey: "lastWorkoutTimestamp") {
        didSet { UserDefaults.standard.set(lastWorkoutTimestamp, forKey: "lastWorkoutTimestamp") }
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
        // 暫時先只解鎖前四棵，其餘顯示 x0
        guard plantID <= 4 else { return 0 }
        guard let entry = plantCatalog.first(where: { $0.id == plantID }) else { return 0 }
        guard totalSetsCompleted > 0 else { return 0 }
        return max(totalSetsCompleted / entry.unlockTarget, 0)
    }
    
    var quickStartExercise: Exercise? {
        if lastExerciseName.isEmpty { return exercises.first }
        return exercises.first(where: { $0.name == lastExerciseName }) ?? exercises.first
    }

    var hasWorkoutToday: Bool {
        guard lastWorkoutTimestamp > 0 else { return false }
        return Calendar.current.isDateInToday(Date(timeIntervalSince1970: lastWorkoutTimestamp))
    }

    var ringProgress: CGFloat {
        CGFloat(min(max(plantHydration / 100.0, 0), 1))
    }

    var hydrationLevel: Int {
        let step = 100.0 / Double(currentPlant.unlockTarget)
        return min(max(Int(ceil(plantHydration / step)), 1), currentPlant.unlockTarget)
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

    // MARK: - Actions

    func startExercise(_ exercise: Exercise) {
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
        pendingWaterGain += 5.0

        lastExerciseName    = exercise.name
        lastWeight          = weightKg
        lastReps            = selectedReps
        lastWorkoutTimestamp = Date().timeIntervalSince1970
        totalSetsCompleted  += 1

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if currentSet >= totalSets {
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

    func finishAndGoHome() {
        plantHydration = min(plantHydration + pendingWaterGain, 100)
        withAnimation(.spring(duration: 0.6)) { plantScale = 1.10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(duration: 0.4)) { self.plantScale = 1.0 }
        }
        resetSession()
        screen = .home
    }

    func choosePlant(_ plant: PlantCatalogEntry) {
        selectedPlantID = plant.id
        withAnimation(.easeInOut(duration: 0.35)) {
            homeTab = .tree
        }
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
