import Foundation
import SwiftData
import SwiftUI

// MARK: - Exercise catalog

struct Exercise: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var muscleGroup: String
    var defaultSets: Int
    var restSeconds: Int
    var defaultWeightKg: Double

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: String,
        defaultSets: Int,
        restSeconds: Int,
        defaultWeightKg: Double = 0
    ) {
        self.id          = id
        self.name        = name
        self.muscleGroup = muscleGroup
        self.defaultSets = defaultSets
        self.restSeconds = restSeconds
        self.defaultWeightKg = max(0, defaultWeightKg)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, muscleGroup, defaultSets, restSeconds, defaultWeightKg
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        muscleGroup = try c.decode(String.self, forKey: .muscleGroup)
        defaultSets = try c.decode(Int.self, forKey: .defaultSets)
        restSeconds = try c.decode(Int.self, forKey: .restSeconds)
        defaultWeightKg = max(0, (try c.decodeIfPresent(Double.self, forKey: .defaultWeightKg)) ?? 0)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(muscleGroup, forKey: .muscleGroup)
        try c.encode(defaultSets, forKey: .defaultSets)
        try c.encode(restSeconds, forKey: .restSeconds)
        try c.encode(defaultWeightKg, forKey: .defaultWeightKg)
    }
}

// MARK: - Workout session

struct SetRecord {
    let setNumber: Int
    let reps: Int
    let weight: Double
    let startedAt: Date
    let completedAt: Date = .now

    var exerciseDuration: TimeInterval {
        completedAt.timeIntervalSince(startedAt)
    }
}

// MARK: - Units

enum WeightUnit: String {
    case kg
    case lb
}

// MARK: - Plant catalog

struct PlantCatalogEntry: Identifiable {
    let id: Int
    let name: String
    let englishName: String
    let quote: String
    let unlockTarget: Int
    let imagePath: String
    let lockImagePath: String

    static let fallback = PlantCatalogEntry(
        id: 0, name: "綠蘿", englishName: "Epipremnum aureum",
        quote: "持續訓練，慢慢成長", unlockTarget: 5,
        imagePath: "drawable/home_plant1", lockImagePath: "drawable/home_plant1_lock"
    )

    static let unselected = PlantCatalogEntry(
        id: 0, name: "尚未選擇花盆", englishName: "No pot selected",
        quote: "先前往花園選擇今天要栽培的花盆", unlockTarget: 0,
        imagePath: "drawable/task", lockImagePath: "drawable/task"
    )
}

private let plantSymbolCatalog: [String] = [
    "leaf.fill",
    "tree.fill",
    "camera.macro",
    "sparkles",
    "sun.max.fill",
    "moon.stars.fill",
    "drop.fill",
    "flame.fill",
    "bolt.fill",
    "hare.fill",
    "tortoise.fill",
    "bird.fill",
    "ladybug.fill",
    "pawprint.fill",
    "star.fill",
    "heart.fill",
    "diamond.fill",
    "seal.fill",
    "crown.fill",
    "bell.fill",
    "cloud.fill",
    "wind",
    "snowflake",
    "rainbow",
    "mountain.2.fill",
    "globe.asia.australia.fill",
    "fan.fill",
    "atom"
]

private func symbolIndex(for plantID: Int) -> Int {
    guard !plantSymbolCatalog.isEmpty else { return 0 }
    return abs(plantID - 1) % plantSymbolCatalog.count
}

func plantSymbolName(for plantID: Int) -> String {
    plantSymbolCatalog[symbolIndex(for: plantID)]
}

private func plantSymbolTint(for plantID: Int) -> Color {
    let hues: [Double] = [0.34, 0.44, 0.54, 0.08, 0.16, 0.72, 0.88, 0.24]
    return Color(hue: hues[abs(plantID) % hues.count], saturation: 0.62, brightness: 0.75)
}

struct PlantSymbolBadge: View {
    let plantID: Int
    let isUnlocked: Bool
    var size: CGFloat = 86
    var showLockOverlay: Bool = false

    private var tint: Color {
        plantSymbolTint(for: plantID)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(isUnlocked ? tint.opacity(0.18) : Color.gray.opacity(0.16))
                .overlay(
                    Circle()
                        .stroke(isUnlocked ? tint.opacity(0.65) : Color.gray.opacity(0.45), lineWidth: 2)
                )
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: isUnlocked ? plantSymbolName(for: plantID) : "lock.fill")
                        .font(.system(size: size * 0.38, weight: .bold))
                        .foregroundStyle(isUnlocked ? tint : Color.gray.opacity(0.9))
                )

            if showLockOverlay && !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: max(11, size * 0.15), weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .background(Color.black.opacity(0.62))
                    .clipShape(Circle())
                    .offset(x: 4, y: -4)
            }
        }
    }
}



// MARK: - Planting history

struct PlantingRecord: Identifiable, Codable {
    let id: UUID
    var plantID: Int
    var plantName: String
    var completedAt: Date
    var rewardMessage: String

    init(id: UUID = UUID(), plantID: Int, plantName: String, completedAt: Date = .now, rewardMessage: String) {
        self.id = id
        self.plantID = plantID
        self.plantName = plantName
        self.completedAt = completedAt
        self.rewardMessage = rewardMessage
    }
}

// MARK: - SwiftData: WorkoutSession

@Model
final class WorkoutSession {
    var id: UUID
    var exerciseName: String
    var muscleGroup: String
    var date: Date
    var totalSets: Int
    var notes: String

    @Relationship(deleteRule: .cascade)
    var sets: [WorkoutSet] = []

    // Supabase sync fields
    var supabaseID: String?
    var syncedAt: Date?
    var isDirty: Bool

    init(exerciseName: String, muscleGroup: String, date: Date = .now, totalSets: Int, notes: String = "") {
        self.id           = UUID()
        self.exerciseName = exerciseName
        self.muscleGroup  = muscleGroup
        self.date         = date
        self.totalSets    = totalSets
        self.notes        = notes
        self.isDirty      = true
    }

    var maxWeight: Double { sets.map(\.weightKg).max() ?? 0 }
    var totalVolume: Double { sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) } }
}

// MARK: - SwiftData: WorkoutSet

@Model
final class WorkoutSet {
    var id: UUID
    var setNumber: Int
    var reps: Int
    var weightKg: Double
    var completedAt: Date
    var session: WorkoutSession?
    var supabaseID: String?

    init(setNumber: Int, reps: Int, weightKg: Double, completedAt: Date = .now) {
        self.id          = UUID()
        self.setNumber   = setNumber
        self.reps        = reps
        self.weightKg    = weightKg
        self.completedAt = completedAt
    }
}

// MARK: - Navigation enums

enum HomeTab {
    case tree
    case garden
}

enum AppScreen {
    case home
    case dictionary
    case workout
    case workoutHistory
    case bodyManagement
    case workoutPlan
    case achievements
    case settings
}

enum DietStatus: String, Codable, CaseIterable, Identifiable {
    case light
    case normal
    case indulgent
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "輕盈"
        case .normal: return "一般"
        case .indulgent: return "罪惡"
        case .unknown: return "？"
        }
    }

    var icon: String {
        switch self {
        case .light: return "leaf.fill"
        case .normal: return "circle.grid.2x2.fill"
        case .indulgent: return "birthday.cake.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

struct WeightLogEntry: Identifiable, Codable {
    let id: UUID
    var date: Date
    var weightKg: Double

    init(id: UUID = UUID(), date: Date = .now, weightKg: Double) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
    }
}

// MARK: - Workout Plan

struct WorkoutPlan: Identifiable, Codable {
    let id: UUID
    var name: String
    var items: [WorkoutPlanItem]

    init(id: UUID = UUID(), name: String, items: [WorkoutPlanItem] = []) {
        self.id = id; self.name = name; self.items = items
    }
}

struct WorkoutPlanItem: Identifiable, Codable {
    let id: UUID
    var exerciseID: UUID
    var exerciseName: String
    var muscleGroup: String
    var sets: Int
    var targetReps: Int
    var targetWeightKg: Double

    init(id: UUID = UUID(), exerciseID: UUID, exerciseName: String, muscleGroup: String,
         sets: Int = 4, targetReps: Int = 10, targetWeightKg: Double = 20) {
        self.id = id; self.exerciseID = exerciseID; self.exerciseName = exerciseName
        self.muscleGroup = muscleGroup; self.sets = sets
        self.targetReps = targetReps; self.targetWeightKg = targetWeightKg
    }
}

enum WorkoutPhase {
    case training, repsPicker, resting, summary
}
