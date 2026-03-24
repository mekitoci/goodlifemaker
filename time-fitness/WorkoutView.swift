import SwiftUI
import Charts

// MARK: - Workout router

struct WorkoutView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            switch state.workoutPhase {
            case .training:
                TrainingView()
            case .repsPicker:
                TrainingView()
                    .overlay(RepsPickerOverlay())
            case .resting:
                RestView()
            case .summary:
                SummaryView()
            }

            if state.editingWeight {
                WeightEditSheet()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state.editingWeight)
        .animation(.easeInOut(duration: 0.35), value: state.workoutPhase)
    }
}

// MARK: - Training (紅色)

private struct TrainingView: View {
    @Environment(AppState.self) private var state
    private let sidePadding: CGFloat = 24
    private let cardRadius: CGFloat = 22

    var body: some View {
        ZStack {
            Color(red: 0.82, green: 0.18, blue: 0.18).ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                    .padding(.horizontal, sidePadding)
                    .padding(.top, 14)

                Spacer()
                Text("專注組間休息")
                    .font(.headline.bold())
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, sidePadding)
                    .padding(.bottom, 10)
                setCounter
                Spacer()

                VStack(spacing: 14) {
                    sessionInfoCard
                    doneButton
                }
                .padding(.horizontal, sidePadding)
                .padding(.bottom, 34)
            }
        }
    }

    private var navBar: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    state.screen = .home
                    state.resetSession()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.white.opacity(0.22))
                    .clipShape(Circle())
            }
            Spacer()
            Spacer()
            if state.currentSet < state.totalSets {
                Button {
                    state.finishExercise()
                } label: {
                    Text("結束訓練")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.22))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var setCounter: some View {
        VStack(spacing: 10) {
            Text("SET")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .tracking(5)
            Text("\(state.currentSet)")
                .font(.system(size: 108, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("/ \(state.totalSets)")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))

            setProgressDots
                .padding(.top, 6)
        }
    }

    // (removed legacy weightButton sheet presenter)

    private var sessionInfoCard: some View {
        return VStack(alignment: .center, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("第 \(state.currentSet) 組 / 共 \(state.totalSets) 組")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.92))
            }
            .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 12) {

                Button {
                    state.selectedReps = max(1, state.selectedReps - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.16))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("\(state.selectedReps)")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(minWidth: 56, alignment: .center)

                Button {
                    state.selectedReps = min(200, state.selectedReps + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.16))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 12) {
                Button {
                    state.weightKg = max(0, state.weightKg - 2.5)
                } label: {
                    Image(systemName: "minus")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.16))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                VStack(spacing: 2) {
                    Text("重量")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.70))
                    Text(state.weightText(fromKg: state.weightKg))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(minWidth: 110, alignment: .center)

                Button {
                    state.weightKg = min(500, state.weightKg + 2.5)
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.16))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
    }

    private var doneButton: some View {
        Button { state.tapDone() } label: {
            Text("Done")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.82, green: 0.18, blue: 0.18))
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var setProgressDots: some View {
        HStack(spacing: 8) {
            ForEach(1...max(state.totalSets, 1), id: \.self) { i in
                Circle()
                    .fill(i < state.currentSet ? Color.white.opacity(0.95) : Color.white.opacity(i == state.currentSet ? 0.55 : 0.18))
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Reps Picker Overlay

private struct RepsPickerOverlay: View {
    @Environment(AppState.self) private var state

    private let repsOptions = [5, 6, 8, 10, 12, 15, 20]
    private let cardRadius: CGFloat = 22

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    // close overlay without confirming
                    state.workoutPhase = .training
                }

            VStack(spacing: 12) {
                Spacer()

                VStack(spacing: 16) {
                    HStack {
                        Text("這組預計做幾下？")
                            .font(.headline.bold())
                            .foregroundStyle(.black.opacity(0.86))
                        Spacer()
                        Button {
                            state.workoutPhase = .training
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.gray)
                                .padding(10)
                                .background(Color(white: 0.94))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                        spacing: 12
                    ) {
                        ForEach(repsOptions, id: \.self) { reps in
                            Button {
                                state.selectedReps = reps
                            } label: {
                                Text("\(reps)")
                                    .font(.title2.bold())
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(state.selectedReps == reps
                                        ? Color(red: 0.82, green: 0.18, blue: 0.18)
                                        : Color(white: 0.94))
                                    .foregroundStyle(state.selectedReps == reps ? .white : .black.opacity(0.82))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 12) {
                        Text("自訂次數")
                            .font(.subheadline)
                            .foregroundStyle(.black.opacity(0.7))

                        Spacer()

                        Button {
                            state.selectedReps = max(1, state.selectedReps - 1)
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black.opacity(0.75))
                                .frame(width: 44, height: 44)
                                .background(Color(white: 0.94))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Text("\(state.selectedReps) 下")
                            .font(.headline.bold())
                            .foregroundStyle(.black.opacity(0.85))
                            .frame(width: 76)

                        Button {
                            state.selectedReps = min(50, state.selectedReps + 1)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black.opacity(0.75))
                                .frame(width: 44, height: 44)
                                .background(Color(white: 0.94))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        // Only set reps, don't log a set yet.
                        withAnimation(.easeInOut(duration: 0.25)) {
                            state.workoutPhase = .training
                        }
                    } label: {
                        Text("確認 \(state.selectedReps) 下")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color(red: 0.82, green: 0.18, blue: 0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Rest (綠色)

private struct RestView: View {
    @Environment(AppState.self) private var state
    private let sidePadding: CGFloat = 24

    var body: some View {
        ZStack {
            Color(red: 0.18, green: 0.62, blue: 0.43).ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                    .padding(.horizontal, sidePadding)
                    .padding(.top, 18)

                Spacer()
                Text("組間休息中")
                    .font(.headline.bold())
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, sidePadding)
                    .padding(.bottom, 10)
                countdownSection
                Spacer()

                restWeightControlCard
                    .padding(.horizontal, sidePadding)
                    .padding(.bottom, 10)

                restActionCard
                    .padding(.horizontal, sidePadding)
                    .padding(.bottom, 38)
            }
        }
    }

    private var navBar: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    state.screen = .home
                    state.resetSession()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.white.opacity(0.22))
                    .clipShape(Circle())
            }
            Spacer()
        }
    }

    private var countdownSection: some View {
        VStack(spacing: 0) {
            Text("下一組：第 \(state.currentSet) 組")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
            Text("\(state.remainingRestSeconds)")
                .font(.system(size: 114, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
                .animation(.linear(duration: 0.25), value: state.remainingRestSeconds)
            Text("秒")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var restActionCard: some View {
        Button {
            state.skipRest()
        } label: {
            Text("跳過休息")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.white.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var restWeightControlCard: some View {
        HStack(spacing: 14) {
            Button {
                state.weightKg = max(0, state.weightKg - 2.5)
            } label: {
                Image(systemName: "minus")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.16))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("重量")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.72))
                Text(state.weightText(fromKg: state.weightKg))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                state.weightKg = min(500, state.weightKg + 2.5)
            } label: {
                Image(systemName: "plus")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.16))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Summary (收穫)

private struct SummaryView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var modelContext
    private let sidePadding: CGFloat = 20
    private let cardRadius: CGFloat = 18
    @State private var isSetLogExpanded: Bool = false

    private var totalVolume: Double {
        state.setRecords.reduce(0) { $0 + (Double($1.reps) * $1.weight) }
    }

    private var maxWeight: Double {
        state.setRecords.map(\.weight).max() ?? 0
    }

    private var averageReps: Double {
        guard !state.setRecords.isEmpty else { return 0 }
        let reps = state.setRecords.reduce(0) { $0 + $1.reps }
        return Double(reps) / Double(state.setRecords.count)
    }

    private struct PacePoint: Identifiable {
        let id = UUID()
        let setNumber: Int
        let durationSeconds: Double
        let label: String
    }

    private var pacePoints: [PacePoint] {
        let records = state.setRecords
        guard !records.isEmpty else { return [] }
        return records.map { r in
            let dur = max(0, r.exerciseDuration)
            let mins = Int(dur) / 60
            let secs = Int(dur) % 60
            let label = mins > 0 ? "\(mins)m\(String(format: "%02d", secs))s" : "\(secs)s"
            return PacePoint(setNumber: r.setNumber, durationSeconds: dur, label: label)
        }
    }

    private var paceYDomain: ClosedRange<Double> {
        guard !pacePoints.isEmpty else { return 0...60 }
        let vals = pacePoints.map(\.durationSeconds)
        let minV = vals.min() ?? 0
        let maxV = vals.max() ?? 0
        let spread = maxV - minV

        if spread < 5 {
            let mid = (minV + maxV) / 2
            let half = max(mid * 0.6, 4)
            return max(0, mid - half)...(mid + half)
        }
        let pad = spread * 0.25
        return max(0, minV - pad)...(maxV + pad)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.14, blue: 0.24),
                    Color(red: 0.26, green: 0.22, blue: 0.48),
                    Color(red: 0.16, green: 0.44, blue: 0.58)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    completionHeroCard
                    summaryStatsCard
                    setLog
                    finishButton
                        .padding(.top, 6)
                        .padding(.bottom, 44)
                }
                .padding(.horizontal, sidePadding)
                .padding(.top, 22)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.55).delay(0.25)) {
                state.showSummaryWater = true
            }
        }
    }

    @State private var heroCheckAppear: Bool = false

    private var completionHeroCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 84, height: 84)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(heroCheckAppear ? 1.0 : 0.5)
                    .opacity(heroCheckAppear ? 1.0 : 0.0)
                    .animation(.spring(duration: 0.5, bounce: 0.4).delay(0.15), value: heroCheckAppear)
            }

            VStack(spacing: 5) {
                Text("訓練完成")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(.white)

                Text("\(state.setRecords.count) 組")
                    .font(.title3.bold())
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear { heroCheckAppear = true }
    }

    private var summaryStatsCard: some View {
        HStack(spacing: 10) {
            summaryMetricPill(title: "總訓練量", value: String(format: "%.0fkg", totalVolume))
            summaryMetricPill(title: "最大重量", value: String(format: "%.1fkg", maxWeight))
            summaryMetricPill(title: "平均次數", value: String(format: "%.1f下", averageReps))
        }
    }

    private func summaryMetricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var setLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSetLogExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("訓練紀錄")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.86))
                    Spacer()
                    Image(systemName: isSetLogExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 2)
            }
            .buttonStyle(.plain)

            if isSetLogExpanded {
                VStack(spacing: 10) {
                    ForEach(state.setRecords.indices, id: \.self) { i in
                        let r = state.setRecords[i]
                        let previousWeight = i > 0 ? state.setRecords[i - 1].weight : r.weight
                        let weightChanged = i > 0 && abs(previousWeight - r.weight) > 0.001

                        HStack {
                            Text("Set \(r.setNumber)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 58, alignment: .leading)
                            Text("\(r.reps) 下")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            if weightChanged {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                                        .font(.caption.bold())
                                    Text(state.weightText(fromKg: r.weight))
                                        .font(.subheadline.bold())
                                }
                                .foregroundStyle(Color(red: 0.82, green: 0.92, blue: 0.46))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                            } else {
                                Text(state.weightText(fromKg: r.weight))
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            } else {
                Text("點擊查看每組紀錄")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.horizontal, 2)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
    }

    private var paceTrendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("每組運動時間")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.86))
                Spacer()
                if !pacePoints.isEmpty {
                    let avg = pacePoints.map(\.durationSeconds).reduce(0, +) / Double(pacePoints.count)
                    let mins = Int(avg) / 60
                    let secs = Int(avg) % 60
                    let avgLabel = mins > 0 ? "平均 \(mins)m\(String(format: "%02d", secs))s" : "平均 \(secs)s"
                    Text(avgLabel)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.14))
                        .clipShape(Capsule())
                }
            }

            if pacePoints.count >= 2 {
                let useSmooth: Bool = pacePoints.count >= 4
                Chart(pacePoints) { point in
                    AreaMark(
                        x: .value("Set", point.setNumber),
                        y: .value("秒", point.durationSeconds)
                    )
                    .interpolationMethod(useSmooth ? .catmullRom : .linear)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white.opacity(0.32), Color.white.opacity(0.06), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Set", point.setNumber),
                        y: .value("秒", point.durationSeconds)
                    )
                    .interpolationMethod(useSmooth ? .catmullRom : .linear)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    PointMark(
                        x: .value("Set", point.setNumber),
                        y: .value("秒", point.durationSeconds)
                    )
                    .foregroundStyle(.white)
                    .symbolSize(44)
                    .annotation(position: .top, spacing: 6) {
                        Text(point.label)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: pacePoints.map(\.setNumber)) { value in
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("S\(v)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.white.opacity(0.6))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(Color.white.opacity(0.12))
                        AxisValueLabel()
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .chartYScale(domain: paceYDomain)
                .chartXScale(domain: (pacePoints.first?.setNumber ?? 1)...(pacePoints.last?.setNumber ?? 2))
                .chartPlotStyle { plot in
                    plot
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .frame(height: 150)
            } else if pacePoints.count == 1 {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundStyle(.cyan.opacity(0.7))
                    Text("第 1 組用時 \(pacePoints[0].label)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .center)
            } else {
                Text("完成訓練後會顯示時間趨勢")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .center)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
    }

    private var finishButton: some View {
        VStack(spacing: 10) {
            Button {
                state.clearActivePlan()
                state.finishAndGoHome(modelContext: modelContext)
            } label: {
                Text("完成")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.30, green: 0.77, blue: 0.95),
                                Color(red: 0.38, green: 0.50, blue: 0.98),
                                Color(red: 0.58, green: 0.46, blue: 0.98)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Safe subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Weight Edit Sheet

struct WeightEditSheet: View {
    @Environment(AppState.self) private var state

    private let suggestions: [Double] = [20, 30, 40, 50, 60, 70, 80, 100]
    private let stepKg: Double = 5
    private let stepLb: Double = 5
    private let softGray = Color(white: 0.94)
    private let brandRed = Color(red: 0.82, green: 0.18, blue: 0.18)
    private let brandGreen = Color(red: 0.30, green: 0.56, blue: 0.50)

    private var stepInCurrentUnit: Double {
        state.weightUnit == .kg ? stepKg : stepLb
    }

    private var unitLabel: String { state.weightUnit == .kg ? "kg" : "lb" }

    private var favoriteWeights: [Double] {
        var items: [Double] = []
        if state.lastWeight > 0 { items.append(state.lastWeight) }
        if state.weightKg > 0 { items.append(state.weightKg) }
        items.append(60)
        // De-dup while keeping order, normalize to one decimal.
        var seen = Set<String>()
        return items.compactMap { w in
            let key = String(format: "%.1f", w)
            if seen.contains(key) { return nil }
            seen.insert(key)
            return (Double(key) ?? w)
        }
        .prefix(3)
        .map { $0 }
    }

    private func applyStep(_ deltaInUnit: Double) {
        let current = state.weightValue(fromKg: state.weightKg)
        let next = max(0, current + deltaInUnit)
        let nextKg = state.kg(fromWeightValue: next, unit: state.weightUnit)
        state.weightKg = nextKg
        let shown = (next.rounded(.down) == next) ? String(Int(next)) : String(format: "%.1f", next)
        state.weightInputText = shown
    }

    private func syncTextFieldFromWeight() {
        let v = state.weightValue(fromKg: state.weightKg)
        let shown = (v.rounded(.down) == v) ? String(Int(v)) : String(format: "%.1f", v)
        state.weightInputText = shown
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    state.editingWeight = false
                }

            VStack(spacing: 12) {
                Spacer()

                VStack(spacing: 16) {
                    HStack {
                        Text("調整重量")
                            .font(.headline.bold())
                            .foregroundStyle(.black.opacity(0.86))
                        Spacer()
                        Button {
                            state.editingWeight = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.gray)
                                .padding(10)
                                .background(softGray)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 0) {
                        ForEach([WeightUnit.kg, WeightUnit.lb], id: \.self) { unit in
                            let selected = state.weightUnit == unit
                            Button {
                                state.weightUnit = unit
                                syncTextFieldFromWeight()
                            } label: {
                                Text(unit == .kg ? "公斤" : "磅")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(selected ? .white : Color(white: 0.4))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selected ? Color(white: 0.2) : Color(white: 0.88))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    // Big value with +/- (same pattern as reps picker)
                    HStack(spacing: 12) {
                        Button { applyStep(-stepInCurrentUnit) } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black.opacity(0.75))
                                .frame(width: 44, height: 44)
                                .background(softGray)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        TextField(unitLabel,
                                  text: Binding(
                                      get: { state.weightInputText },
                                      set: { state.weightInputText = $0 }
                                  ))
                            .font(.system(size: 54, weight: .black))
                            .foregroundStyle(Color.black)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Button { applyStep(stepInCurrentUnit) } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black.opacity(0.75))
                                .frame(width: 44, height: 44)
                                .background(softGray)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    Text("每次調整 \(Int(stepInCurrentUnit)) \(unitLabel)")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !favoriteWeights.isEmpty {
                        HStack(spacing: 10) {
                            Text("常用")
                                .font(.subheadline)
                                .foregroundStyle(.black.opacity(0.6))
                            Spacer()
                        }

                        HStack(spacing: 10) {
                            ForEach(favoriteWeights, id: \.self) { w in
                                Button {
                                    state.weightKg = w
                                    syncTextFieldFromWeight()
                                } label: {
                                    Text(state.weightText(fromKg: w))
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(brandGreen)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                    }

                    HStack(spacing: 10) {
                        Text("快速選擇")
                            .font(.subheadline)
                            .foregroundStyle(.black.opacity(0.6))
                        Spacer()
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(suggestions, id: \.self) { w in
                            let shown = Int(state.weightValue(fromKg: w).rounded())
                            Button {
                                state.weightKg = w
                                syncTextFieldFromWeight()
                            } label: {
                                Text("\(shown)")
                                    .font(.title3.bold())
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(state.weightKg == w ? brandRed : softGray)
                                    .foregroundStyle(state.weightKg == w ? .white : .black.opacity(0.82))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        let raw = state.weightInputText.replacingOccurrences(of: ",", with: ".")
                        if let v = Double(raw), v > 0 {
                            state.weightKg = state.kg(fromWeightValue: v, unit: state.weightUnit)
                        }
                        state.editingWeight = false
                    } label: {
                        Text("確認")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(brandRed)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

#Preview {
    WorkoutView()
        .environment(AppState())
}
