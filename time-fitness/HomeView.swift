import SwiftUI

// MARK: - HomeView

struct HomeView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack(alignment: .leading) {
            Color(red: 0.44, green: 0.62, blue: 0.58).ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    if state.homeTab == .tree {
                        VStack(spacing: 0) {
                            Spacer(minLength: 10)

                            VStack(spacing: 28) {
                                PlantNameRow()
                                PlantRingCard()
                                MotivationLabel()
                            }
                            .padding(.horizontal, 24)

                            Spacer(minLength: 20)

                            QuickStartSection()
                                .padding(.horizontal, 20)
                                .padding(.bottom, 100)
                        }
                        .transition(
                            .move(edge: .leading)
                                .combined(with: .opacity)
                        )
                    }

                    if state.homeTab == .garden {
                        VStack {
                            Spacer(minLength: 8)

                            GardenContentView()
                                .padding(.horizontal, 16)
                                .padding(.top, 6)
                                .padding(.bottom, 100)
                        }
                        .transition(
                            .move(edge: .trailing)
                                .combined(with: .opacity)
                        )
                    }
                }
            }
            .animation(.easeInOut(duration: 0.35), value: state.homeTab)
        }
        .alert("請更換花盆", isPresented: Binding(
            get: { state.showSwitchPotPrompt },
            set: { state.showSwitchPotPrompt = $0 }
        )) {
            Button("前往花園") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    state.homeTab = .garden
                }
            }
            Button("知道了", role: .cancel) {}
        } message: {
            Text(state.switchPotPromptMessage.isEmpty
                 ? "當前盆栽已達 100%，請先選擇其他花盆。"
                 : state.switchPotPromptMessage)
        }

    }
}

// MARK: - PlantNameRow

private struct PlantNameRow: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 6) {
            Text(state.hasSelectedPlant ? state.currentPlant.name : "尚未選擇花盆")
                .font(.system(size: 38, weight: .black))
                .foregroundStyle(.white.opacity(0.96))
                .shadow(color: .black.opacity(0.18), radius: 2, y: 2)

            Text(state.hasSelectedPlant
                 ? "「\(state.currentPlant.quote)」"
                 : "先前往花園選擇今天要栽培的花盆")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PlantRingCard

struct PlantRingCard: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.55), lineWidth: 10)
                .frame(width: 248, height: 248)

            Circle()
                .trim(from: 0.0, to: state.ringProgress)
                .stroke(
                    Color(red: 0.84, green: 0.90, blue: 0.25),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 248, height: 248)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: state.ringProgress)

            Circle()
                .fill(.white.opacity(0.95))
                .frame(width: 214, height: 214)

            ringContent

            // Knob dot that follows the ring tip
            if state.hasSelectedPlant {
                let angle = state.ringProgress * 2 * Double.pi - Double.pi / 2
                Circle()
                    .fill(Color(red: 0.84, green: 0.90, blue: 0.25))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .offset(x: 124 * cos(angle), y: 124 * sin(angle))
                    .animation(.easeInOut(duration: 0.8), value: state.ringProgress)
            }
        }
    }

    private var ringContent: some View {
        VStack(spacing: 0) {
            // 上方：百分比 + 進度
            VStack(spacing: 3) {
                Text(state.hasSelectedPlant ? "\(Int(state.plantHydration))%" : "--")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(.black)
                Text(state.hasSelectedPlant
                     ? "\(state.hydrationLevel)/\(state.currentPlant.unlockTarget)"
                     : "請先選擇花盆")
                    .font(.caption.bold())
                    .foregroundStyle(.gray)
            }
            .padding(.top, 18)

            // 中間彈性空間
            Spacer()

            // 花盆置中於剩餘空間
            ZStack(alignment: .top) {
                if state.hasSelectedPlant {
                    DrawableImage(path: state.currentPlant.imagePath, fallbackColor: state.plantColor)
                        .frame(width: 100, height: 100)
                        .scaleEffect(state.plantScale)
                        .animation(.spring(duration: 0.5, bounce: 0.4), value: state.plantScale)
                } else {
                    Image(systemName: "leaf.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 86, height: 86)
                        .foregroundStyle(Color(red: 0.44, green: 0.62, blue: 0.58).opacity(0.8))
                }

                if state.waterDropVisible, state.hasSelectedPlant {
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { _ in
                            Image(systemName: "drop.fill")
                                .font(.title3)
                                .foregroundStyle(.cyan.opacity(0.85))
                        }
                    }
                    .offset(y: -26)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }

            // 下方彈性空間（讓花盆不貼底）
            Spacer()
                .frame(minHeight: 14)
        }
        .frame(width: 180, height: 210)
    }
}

// MARK: - MotivationLabel

private struct MotivationLabel: View {
    @Environment(AppState.self) private var state
    @State private var quoteIndex: Int = 0
    @State private var visible: Bool = true
    @State private var activeQuotes: [String] = []

    private let cycleTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    private static let pool: [(range: ClosedRange<Double>, quotes: [String])] = [
        (0...14, [
            "每一次訓練，都是對自己的承諾",
            "開始永遠不嫌晚，今天就是最好的時機",
            "改變從第一步開始",
            "身體記得你每一次的付出"
        ]),
        (15...29, [
            "小小的積累，終將成為巨大的改變",
            "堅持不是天賦，而是選擇",
            "你今天的努力，是明天的基礎",
            "過程比結果更值得驕傲"
        ]),
        (30...49, [
            "你已經走了三分之一，別讓自己後悔",
            "節奏對了，剩下的就交給時間",
            "不需要完美，只需要繼續",
            "每次訓練都在重塑更好的你"
        ]),
        (50...69, [
            "超過一半了，你比想像中更有毅力",
            "持續的力量遠勝過短暫的爆發",
            "你已經證明了自己能做到",
            "中途是最難的地方，你已經過了"
        ]),
        (70...84, [
            "終點就在前方，不要停下來",
            "這段路不容易，但你一直在走",
            "快到了，讓身體感受到那個瞬間",
            "每一滴汗都值得"
        ]),
        (85...99, [
            "差一點就完成了，再堅持一下",
            "你能感受到植物在等待你",
            "最後的衝刺，往往決定整段旅程",
            "就快了，不要放棄在這裡"
        ]),
        (100...100, [
            "完全解鎖，你做到了",
            "從種子到大樹，見證了你的堅持",
            "這段旅程值得記住",
            "你的努力，植物都感受到了"
        ])
    ]

    private func quotes(for hydration: Double) -> [String] {
        let pct = hydration
        return Self.pool.first(where: { $0.range.contains(pct) })?.quotes
            ?? Self.pool.last!.quotes
    }

    var body: some View {
        Group {
            if visible {
                Text(displayQuote)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: visible)
        .onAppear {
            syncQuotesWithHydration(resetIndex: true)
        }
        .onChange(of: state.plantHydration, initial: false) { _, _ in
            syncQuotesWithHydration(resetIndex: false)
        }
        .onReceive(cycleTimer) { _ in
            rotateQuote()
        }
    }

    private var displayQuote: String {
        if activeQuotes.isEmpty {
            return quotes(for: state.plantHydration).first ?? ""
        }
        return activeQuotes[quoteIndex % activeQuotes.count]
    }

    private func syncQuotesWithHydration(resetIndex: Bool) {
        let nextQuotes = quotes(for: state.plantHydration)
        let changedPool = nextQuotes != activeQuotes
        guard changedPool || activeQuotes.isEmpty || resetIndex else { return }

        activeQuotes = nextQuotes
        guard !activeQuotes.isEmpty else {
            quoteIndex = 0
            return
        }

        if resetIndex {
            // 以當前秒數為初始 index，避免每次都從同一句開始
            quoteIndex = Int(Date().timeIntervalSince1970) % activeQuotes.count
        } else {
            quoteIndex = quoteIndex % activeQuotes.count
        }

        visible = true
    }

    private func rotateQuote() {
        guard visible else { return }
        guard activeQuotes.count > 1 else { return }

        withAnimation(.easeInOut(duration: 0.35)) { visible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            quoteIndex = (quoteIndex + 1) % activeQuotes.count
            withAnimation(.easeInOut(duration: 0.35)) { visible = true }
        }
    }
}

// MARK: - QuickStartSection

private struct QuickStartSection: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 12) {
            // 若有菜單正在執行，顯示菜單當前動作卡
            if let planItem = state.activePlanItem,
               let ex = state.exercises.first(where: { $0.id == planItem.exerciseID }) {
                planItemCard(item: planItem, exercise: ex)
            } else {
                // 今日狀態摘要卡
                todayStatsCard
            }

            // 底部雙按鈕：選擇動作 / 選擇菜單（各一半）
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        state.screen = .dictionary
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 15, weight: .semibold))
                        Text("選擇動作")
                            .font(.headline.bold())
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        state.screen = .workoutPlan
                    }
                } label: {
                    HStack(spacing: 8) {
                        DrawableImage(path: "drawable/task", fallbackColor: .white.opacity(0.7))
                            .frame(width: 16, height: 16)
                        Text("選擇菜單")
                            .font(.headline.bold())
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(.white.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            state.refreshHealthKitTodayStatsIfNeeded(force: true)
        }
    }

    // 菜單執行中的卡片
    private func planItemCard(item: WorkoutPlanItem, exercise: Exercise) -> some View {
        Button { state.startExercise(exercise) } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        DrawableImage(path: "drawable/task", fallbackColor: .white.opacity(0.7))
                            .frame(width: 13, height: 13)
                        Text("菜單第 \(state.activePlanIndex + 1) 個")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    Text(exercise.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("\(item.sets) 組 · \(Int(item.targetWeightKg)) kg · 目標 \(item.targetReps) 下")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Text("開始")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(.white.opacity(0.25))
                    .clipShape(Capsule())
            }
            .padding(18)
            .background(Color(red: 0.25, green: 0.50, blue: 0.60))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    // 今日狀態摘要卡
    private var todayStatsCard: some View {
        let calorieBarProgress = min(max(state.todayTotalCalories / 900.0, 0.0), 1.0)

        return HStack(spacing: 12) {
            // 左側：消耗主資訊
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.orange.opacity(0.95))
                    Text("今日消耗")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.86))
                }

                Spacer(minLength: 8)

                Text("\(Int(state.todayTotalCalories)) kcal")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())

                Spacer(minLength: 10)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.16))
                            .frame(height: 10)
                        if calorieBarProgress > 0 {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange.opacity(0.7), .yellow, .orange.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: proxy.size.width * calorieBarProgress, height: 10)
                        }
                    }
                }
                .frame(height: 10)
                .animation(.easeInOut(duration: 0.8), value: state.todayTotalCalories)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(height: 134)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // 右側雙列統計（更俐落）
            VStack(spacing: 10) {
                statRowTile(
                    icon: "figure.walk",
                    iconColor: Color(red: 0.86, green: 0.89, blue: 0.41),
                    value: "\(state.todayStepCount)",
                    label: "今日步數"
                )
                statRowTile(
                    icon: "figure.run",
                    iconColor: .orange.opacity(0.9),
                    value: "\(state.todayActivityCount)",
                    label: "今日運動次數"
                )
            }
            .frame(width: 154)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func statRowTile(icon: String, iconColor: Color, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(iconColor)
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(height: 62)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
