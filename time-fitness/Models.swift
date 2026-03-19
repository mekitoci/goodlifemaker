import Foundation
import SwiftData

// MARK: - Exercise catalog

struct Exercise: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var muscleGroup: String
    var defaultSets: Int
    var restSeconds: Int

    init(id: UUID = UUID(), name: String, muscleGroup: String, defaultSets: Int, restSeconds: Int) {
        self.id          = id
        self.name        = name
        self.muscleGroup = muscleGroup
        self.defaultSets = defaultSets
        self.restSeconds = restSeconds
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
    case workoutPlan
    case achievements
    case settings
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
