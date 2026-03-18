import Foundation

// MARK: - Exercise catalog

struct Exercise: Identifiable {
    let id = UUID()
    let name: String
    let muscleGroup: String
    let defaultSets: Int
    let restSeconds: Int
}

// MARK: - Workout session

struct SetRecord {
    let setNumber: Int
    let reps: Int
    let weight: Double
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
    case achievements
    case settings
}

enum WorkoutPhase {
    case training, repsPicker, resting, summary
}
