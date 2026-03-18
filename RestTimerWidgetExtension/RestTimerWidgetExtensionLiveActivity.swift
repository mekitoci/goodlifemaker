import ActivityKit
import WidgetKit
import SwiftUI

private let green = Color(red: 0.18, green: 0.62, blue: 0.43)

struct RestTimerWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            LockScreenBannerView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展開佈局保持不變
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(green)
                        Text(context.state.exerciseName)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SetDotsView(currentSet: context.state.currentSet, totalSets: context.state.totalSets)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                            .monospacedDigit()
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(green)
                        Spacer()
                        Text("秒後開始下一組")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(green)
                    Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        .monospacedDigit()
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(green)
                }
                .padding(.leading, 4)
            } compactTrailing: {
                SetDotsView(
                    currentSet: context.state.currentSet,
                    totalSets: context.state.totalSets,
                    dotSize: 8,
                    dotSpacing: 5,
                    lineWidth: 1.5
                )
                .padding(.trailing, 4)
            } minimal: {
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(green)
            }
            .keylineTint(green)
        }
    }
}

// MARK: - Lock Screen Banner (保持原樣)

private struct LockScreenBannerView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(green).frame(width: 46, height: 46)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("休息中 · \(context.state.exerciseName)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(green)
            }
            Spacer()
            SetDotsView(currentSet: context.state.currentSet, totalSets: context.state.totalSets)
        }
        .padding(16)
        .activityBackgroundTint(Color(.systemBackground))
    }
}

// MARK: - Set Dots (支援動態尺寸)

private struct SetDotsView: View {
    let currentSet: Int
    let totalSets: Int
    
    // 透過參數控制尺寸，讓動態島可以傳入更小的值
    var dotSize: CGFloat = 8
    var dotSpacing: CGFloat = 5
    var lineWidth: CGFloat = 1.5

    var body: some View {
        HStack(spacing: dotSpacing) {
            // 限制最大顯示數量，防止 totalSets 太大時撐爆動態島
            ForEach(1...min(max(1, totalSets), 6), id: \.self) { i in
                Circle()
                    .fill(i < currentSet ? green : Color.clear)
                    .overlay(
                        Circle().stroke(i < currentSet ? green : green.opacity(0.4), lineWidth: lineWidth)
                    )
                    .frame(width: dotSize, height: dotSize)
            }
        }
    }
}