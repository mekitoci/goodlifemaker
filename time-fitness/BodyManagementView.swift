import SwiftUI
import SwiftData
import Charts

struct BodyManagementView: View {
    @Environment(AppState.self) private var state
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    @State private var weightInput: String = ""
    @State private var weekTrendMode: WeekTrendMode = .calories
    @State private var isTodayWeightLocked: Bool = false
    @State private var editingDietDate: Date? = nil
    @State private var showDietStatusEditor: Bool = false
    @State private var showShareComposer: Bool = false

    private let bg = Color(red: 0.44, green: 0.62, blue: 0.58)
    private let card = Color(red: 0.31, green: 0.56, blue: 0.52)
    private let accent = Color(red: 0.86, green: 0.89, blue: 0.41)

    private struct CalorieDay: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private struct WeightDay: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private enum WeekTrendMode: String, CaseIterable, Identifiable {
        case calories
        case weight

        var id: String { rawValue }

        var title: String {
            switch self {
            case .calories: return "消耗"
            case .weight: return "體重"
            }
        }
    }

    private var monthDays: [CalorieDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<30).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            return CalorieDay(date: day, value: calories(on: day))
        }
    }

    private var weekDays: [CalorieDay] {
        Array(monthDays.suffix(7))
    }

    private var monthTotal: Double {
        monthDays.reduce(0) { $0 + $1.value }
    }

    private var weekAverage: Double {
        guard !weekDays.isEmpty else { return 0 }
        return weekDays.reduce(0) { $0 + $1.value } / Double(weekDays.count)
    }

    private var weekWeightDays: [WeightDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let lookup: [Date: Double] = Dictionary(
            uniqueKeysWithValues: state.weightLogs.map { (cal.startOfDay(for: $0.date), $0.weightKg) }
        )

        return (0..<7).reversed().compactMap { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            guard let weight = lookup[day] else { return nil }
            return WeightDay(date: day, value: weight)
        }
    }

    private var weightTrend: [WeightLogEntry] {
        Array(state.weightLogs.suffix(30))
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        statsCards
                        weekTrendCard
                        monthHeatmapCard
                        weightInputCard
                        // shareButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .onAppear {
            syncTodayWeightState()
        }
        .confirmationDialog(
            editingDietDate.map { "設定 \($0.formatted(date: .abbreviated, time: .omitted)) 的飲食狀況" } ?? "設定飲食狀況",
            isPresented: $showDietStatusEditor
        ) {
            if let date = editingDietDate {
                ForEach(DietStatus.allCases.filter { $0 != .unknown }) { status in
                    Button(status.title) { setDietStatus(status, on: date) }
                }
                Button("清除狀態", role: .destructive) { clearDietStatus(on: date) }
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showShareComposer) {
            ShareExportView(
                title: "體態管理分享",
                styleTitles: ["經典", "卡片", "簡約"],
                renderPage: { style in
                    AnyView(
                        BodyManagementShareCard(
                            style: style,
                            dietDays: monthDietShareDays,
                            today: state.todayTotalCalories,
                            weekAvg: weekAverage,
                            monthTotal: monthTotal
                        )
                    )
                }
            )
        }
    }

    private var navBar: some View {
        HStack {
            Spacer()
                .frame(width: 40)

            Spacer()

            VStack(spacing: 1) {
                Text("體態管理")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
            }

            Spacer()
            Spacer().frame(width: 40)
        }
    }

    private var statsCards: some View {
        HStack(spacing: 10) {
            statPill(title: "今日消耗", value: "\(Int(state.todayTotalCalories)) kcal")
            statPill(title: "7日平均", value: "\(Int(weekAverage)) kcal")
            statPill(title: "30日累積", value: "\(Int(monthTotal)) kcal")
        }
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var weekTrendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("每週趨勢")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                HStack(spacing: 6) {
                    ForEach(WeekTrendMode.allCases) { mode in
                        Button {
                            weekTrendMode = mode
                        } label: {
                            Text(mode.title)
                                .font(.caption.bold())
                                .foregroundStyle(weekTrendMode == mode ? card : .white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(weekTrendMode == mode ? accent : Color.white.opacity(0.14))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if weekTrendMode == .calories {
                Chart(weekDays) { day in
                    LineMark(
                        x: .value("日", day.date, unit: .day),
                        y: .value("kcal", day.value)
                    )
                    .foregroundStyle(accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("日", day.date, unit: .day),
                        y: .value("kcal", day.value)
                    )
                    .foregroundStyle(accent.opacity(0.2))

                    PointMark(
                        x: .value("日", day.date, unit: .day),
                        y: .value("kcal", day.value)
                    )
                    .foregroundStyle(.white)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(Color.white.opacity(0.14))
                        AxisValueLabel()
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .chartPlotStyle { plot in
                    plot
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .frame(height: 180)
            } else if weekWeightDays.count >= 2 {
                Chart(weekWeightDays) { day in
                    LineMark(
                        x: .value("日", day.date, unit: .day),
                        y: .value("kg", day.value)
                    )
                    .foregroundStyle(.white)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value("日", day.date, unit: .day),
                        y: .value("kg", day.value)
                    )
                    .foregroundStyle(accent)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(Color.white.opacity(0.14))
                        AxisValueLabel()
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .chartPlotStyle { plot in
                    plot
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .frame(height: 180)
            } else {
                Text("本週至少需要 2 筆體重紀錄才可顯示趨勢")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .center)
            }
        }
        .padding(14)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var monthHeatmapCard: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        let weekLabels = ["日", "一", "二", "三", "四", "五", "六"]
        let cal = Calendar.current
        let startWeekday = max(0, cal.component(.weekday, from: monthDays.first?.date ?? .now) - 1)

        return VStack(alignment: .leading, spacing: 10) {
            Text("近 30 天飲食狀況")
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.9))

            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(weekLabels, id: \.self) { w in
                    Text(w)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(0..<startWeekday, id: \.self) { _ in
                    Color.clear.frame(height: 26)
                }
                ForEach(monthDays) { day in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(heatColor(value: day.value))
                        .frame(height: 26)
                        .overlay(
                            Text(dietStatusText(on: day.date))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.92))
                        )
                        .onTapGesture {
                            editingDietDate = day.date
                            showDietStatusEditor = true
                        }
                }
            }
        }
        .padding(14)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var shareButton: some View {
        Button {
            showShareComposer = true
        } label: {
            Label("分享", systemImage: "square.and.arrow.up")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var weightInputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("本日體重紀錄")
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.9))

            HStack(spacing: 8) {
                TextField("輸入今日體重（kg）", text: $weightInput)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(.black.opacity(0.82))
                    .disabled(isTodayWeightLocked)
                    .opacity(isTodayWeightLocked ? 0.75 : 1)

                Button(isTodayWeightLocked ? "編輯" : "儲存") {
                    if isTodayWeightLocked {
                        isTodayWeightLocked = false
                        return
                    }

                    let normalized = weightInput.replacingOccurrences(of: ",", with: ".")
                    if let value = Double(normalized), value >= 20, value <= 300 {
                        state.addWeightLogToday(value)
                        isTodayWeightLocked = true
                    }
                }
                .font(.subheadline.bold())
                .foregroundStyle(card)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .buttonStyle(.plain)
            }

            if isTodayWeightLocked {
                Text("已儲存今日體重，可點「編輯」修改")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                Text("輸入有效範圍 20~300 kg")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(14)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func calories(on day: Date) -> Double {
        let cal = Calendar.current
        let records = sessions.filter { cal.isDate($0.date, inSameDayAs: day) }
        return records.reduce(0) { sum, session in
            sum + session.sets.reduce(0) { $0 + Double($1.reps) * $1.weightKg * 0.08 }
        }
    }

    private func heatColor(value: Double) -> Color {
        switch value {
        case ..<0.1:
            return Color.white.opacity(0.08)
        case 0...500:
            return Color(red: 0.62, green: 0.76, blue: 0.59)
        case 500...1000:
            return Color(red: 0.87, green: 0.83, blue: 0.35)
        case 1000...1500:
            return Color(red: 0.90, green: 0.63, blue: 0.30)
        case 1500...2000:
            return Color(red: 0.86, green: 0.41, blue: 0.33)
        default:
            return Color(red: 0.74, green: 0.26, blue: 0.33)
        }
    }

    private func dietStatusText(on date: Date) -> String {
        let key = Self.heatmapDateFormatter.string(from: date)
        guard let raw = state.dietStatusByDate[key], let status = DietStatus(rawValue: raw) else {
            return "-"
        }
        return status.title
    }

    private func setDietStatus(_ status: DietStatus, on date: Date) {
        let key = Self.heatmapDateFormatter.string(from: date)
        state.dietStatusByDate[key] = status.rawValue
    }

    private func clearDietStatus(on date: Date) {
        let key = Self.heatmapDateFormatter.string(from: date)
        state.dietStatusByDate.removeValue(forKey: key)
    }

    private func syncTodayWeightState() {
        let today = Calendar.current.startOfDay(for: .now)
        if let todayEntry = state.weightLogs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            weightInput = (todayEntry.weightKg.rounded(.down) == todayEntry.weightKg)
                ? String(Int(todayEntry.weightKg))
                : String(format: "%.1f", todayEntry.weightKg)
            isTodayWeightLocked = true
        } else {
            isTodayWeightLocked = false
        }
    }

    private static let heatmapDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    private var monthDietShareDays: [ShareDietItem] {
        monthDays.map { day in
            let key = Self.heatmapDateFormatter.string(from: day.date)
            let status = state.dietStatusByDate[key].flatMap(DietStatus.init(rawValue:))?.title ?? "-"
            return ShareDietItem(date: day.date, statusText: status, calories: day.value)
        }
    }
}
