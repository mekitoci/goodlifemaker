import SwiftUI

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
                if let name = state.selectedExercise?.name, !name.isEmpty {
                    Text(name)
                        .font(.headline.bold())
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .padding(.horizontal, sidePadding)
                        .padding(.bottom, 10)
                }
                setCounter
                Spacer()

                VStack(spacing: 14) {
                    infoCard
                    doneButton
                }
                .padding(.horizontal, sidePadding)
                .padding(.bottom, 34)
            }
        }
    }

    private var navBar: some View {
        HStack {
            Button { state.screen = .home; state.resetSession() } label: {
                Image(systemName: "xmark")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.white.opacity(0.22))
                    .clipShape(Circle())
            }
            Spacer()
            Spacer()
            Button {
                state.finishExercise()
            } label: {
                Text("完成此動作")
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

    private var infoCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("第 \(state.currentSet) 組 / 共 \(state.totalSets) 組")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.9))
                HStack(spacing: 10) {
                    infoPill(icon: "scalemass.fill", text: state.weightText(fromKg: state.weightKg)) {
                        state.weightInputText = String(Int(state.weightKg))
                        state.editingWeight = true
                    }
                    infoPill(icon: "repeat", text: "\(state.selectedReps) 下") {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            state.workoutPhase = .repsPicker
                        }
                    }
                }
            }
            Spacer()
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

    private func infoPill(icon: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(text)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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
                if let name = state.selectedExercise?.name, !name.isEmpty {
                    Text(name)
                        .font(.headline.bold())
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .padding(.horizontal, sidePadding)
                        .padding(.bottom, 10)
                }
                countdownSection
                Spacer()

                plantWateringCard
                    .padding(.horizontal, sidePadding)
                    .padding(.bottom, 38)
            }
        }
    }

    private var navBar: some View {
        HStack {
            Spacer()
            Button { state.skipRest() } label: {
                Text("跳過休息")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.white.opacity(0.22))
                    .clipShape(Capsule())
            }
        }
    }

    private var countdownSection: some View {
        VStack(spacing: 0) {
            Text("第 \(state.currentSet) 組準備中")
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

    private var plantWateringCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(.white.opacity(0.18))
                .frame(height: 130)

            HStack(spacing: 18) {
                plantWithDrops
                plantInfo
            }
            .padding(.horizontal, 20)
        }
    }

    private var plantWithDrops: some View {
        ZStack(alignment: .top) {
            DrawableImage(path: state.currentPlant.imagePath, fallbackColor: state.plantColor)
                .frame(width: 82, height: 82)
                .scaleEffect(state.waterDropVisible ? 1.10 : 1.0)
                .animation(.spring(duration: 0.4, bounce: 0.5), value: state.waterDropVisible)

            if state.waterDropVisible {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { _ in
                        Image(systemName: "drop.fill")
                            .font(.title3)
                            .foregroundStyle(.cyan.opacity(0.9))
                    }
                }
                .offset(y: -30)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }

    private var plantInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.currentPlant.name)
                .font(.headline.bold())
                .foregroundStyle(.white)
            Text("正在吸收汗水能量")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.28)).frame(height: 8)
                    Capsule()
                        .fill(.cyan)
                        .frame(width: geo.size.width * state.ringProgress, height: 8)
                        .animation(.easeInOut(duration: 0.8), value: state.ringProgress)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Summary (收穫)

private struct SummaryView: View {
    @Environment(AppState.self) private var state
    private let sidePadding: CGFloat = 20
    private let cardRadius: CGFloat = 18
    @State private var animateDrops: Bool = false

    var body: some View {
        ZStack {
            Color(red: 0.44, green: 0.62, blue: 0.58).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header
                    plantAnimation
                    waterGainLabel
                    setLog
                    finishButton
                        .padding(.bottom, 44)
                }
                .padding(.horizontal, sidePadding)
                .padding(.top, 24)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.55).delay(0.25)) {
                state.showSummaryWater = true
            }
            animateDrops = true
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("訓練完成")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(.white)
            if let name = state.selectedExercise?.name {
                Text(name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
    }

    private var plantAnimation: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 176, height: 176)

            DrawableImage(path: state.currentPlant.imagePath, fallbackColor: state.plantColor)
                .frame(width: 132, height: 132)
                .scaleEffect(state.showSummaryWater ? 1.10 : 1.0)
                .animation(.spring(duration: 0.65, bounce: 0.35).delay(0.25), value: state.showSummaryWater)

            if state.showSummaryWater {
                ForEach(0..<6, id: \.self) { i in
                    let angle = Double(i) * 60.0 * .pi / 180
                    let baseX = 78 * cos(angle)
                    let baseY = 78 * sin(angle)
                    Image(systemName: "drop.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.98),
                                    Color.cyan.opacity(0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Image(systemName: "drop.fill")
                                .font(.title2)
                                .foregroundStyle(Color.white.opacity(0.9))
                                .blur(radius: 0.2)
                        )
                        .shadow(color: .cyan.opacity(0.45), radius: 8, y: 2)
                        .shadow(color: .white.opacity(0.25), radius: 3, y: 1)
                        .opacity(animateDrops ? 1.0 : 0.65)
                        .scaleEffect(animateDrops ? 1.12 : 0.92)
                        .offset(x: baseX, y: baseY + (animateDrops ? -6 : 6))
                        .animation(
                            .easeInOut(duration: 1.1)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.08),
                            value: animateDrops
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var waterGainLabel: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.22))
                    .frame(width: 44, height: 44)
                Image(systemName: "drop.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("+\(Int(state.pendingWaterGain))% 水分")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.22))
                    .clipShape(Capsule())
                Text("累積 \(state.setRecords.count) 組汗水能量")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
    }

    private var setLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("訓練紀錄")
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 2)

            VStack(spacing: 10) {
                ForEach(state.setRecords.indices, id: \.self) { i in
                    let r = state.setRecords[i]
                    HStack {
                        Text("Set \(r.setNumber)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 58, alignment: .leading)
                        Spacer()
                        Text(state.weightText(fromKg: r.weight))
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                        Text("×")
                            .foregroundStyle(.white.opacity(0.4))
                        Text("\(r.reps) 下")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private var finishButton: some View {
        Button { state.finishAndGoHome() } label: {
            HStack(spacing: 8) {
                Text("灌溉植物，回到花園")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color(red: 0.28, green: 0.55, blue: 0.48))
            .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
        }
        .buttonStyle(.plain)
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
