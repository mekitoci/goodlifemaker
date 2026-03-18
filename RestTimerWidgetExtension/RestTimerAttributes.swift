import ActivityKit
import Foundation

struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 休息結束的時間點（timerInterval 自動倒數，不需要每秒 update）
        var endDate: Date
        var totalSeconds: Int
        var exerciseName: String
        var currentSet: Int
        var totalSets: Int
    }
}
