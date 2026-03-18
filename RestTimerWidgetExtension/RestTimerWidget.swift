import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity Widget

struct RestTimerWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // 鎖定畫面 / 通知橫幅 UI
            LockScreenRestView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展開後的完整 Dynamic Island 視圖
                DynamicIslandExpandedRegion(.center) {
                    ExpandedRestView(context: context)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(Color(red: 0.18, green: 0.62, blue: 0.43))
                    .font(.system(size: 14, weight: .semibold))
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 36)
            } minimal: {
                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Lock Screen Banner

private struct LockScreenRestView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.18, green: 0.62, blue: 0.43))
                    .frame(width: 48, height: 48)
                Image(systemName: "timer")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("休息中 · \(context.state.exerciseName)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.18, green: 0.62, blue: 0.43))
            }

            Spacer()

            // 環形進度
            CircularTimerView(
                endDate: context.state.endDate,
                totalSeconds: context.state.totalSeconds
            )
        }
        .padding(16)
        .background(Color(.systemBackground))
    }
}

// MARK: - Expanded Dynamic Island

private struct ExpandedRestView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        VStack(spacing: 6) {
            Text(context.state.exerciseName)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                .font(.system(size: 32, weight: .black))
                .monospacedDigit()
                .foregroundStyle(Color(red: 0.18, green: 0.62, blue: 0.43))

            Text("休息時間")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Circular Progress (Lock Screen)

private struct CircularTimerView: View {
    let endDate: Date
    let totalSeconds: Int

    var body: some View {
        TimelineView(.animation(minimumInterval: 1)) { timeline in
            let remaining = max(0, endDate.timeIntervalSince(timeline.date))
            let progress = CGFloat(remaining) / CGFloat(max(1, totalSeconds))
            ZStack {
                Circle()
                    .stroke(Color(red: 0.18, green: 0.62, blue: 0.43).opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color(red: 0.18, green: 0.62, blue: 0.43),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
            }
            .frame(width: 40, height: 40)
        }
    }
}

// MARK: - Widget Bundle（如果 extension 只有這一個 widget 就不需要，但保留以便擴充）

@main
struct RestTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        RestTimerWidget()
    }
}
