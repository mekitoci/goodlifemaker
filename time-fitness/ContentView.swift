import SwiftUI
import SwiftData
import Charts
import UIKit

struct ContentView: View {
    @State private var state = AppState()

    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .leading) {
                Group {
                    switch state.screen {
                    case .home:           HomeView()
                    case .dictionary:     DictionaryView()
                    case .workout:        WorkoutView()
                    case .workoutHistory: WorkoutHistoryView()
                    case .workoutPlan:    WorkoutPlanView()
                    case .achievements:   AchievementsView()
                    case .settings:       SettingsView()
                    }
                }
                .toolbar(.hidden, for: .navigationBar)

                if state.showGlobalMenu {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                state.showGlobalMenu = false
                            }
                        }

                    AppSideMenuView(
                        onSelectMyTree: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                state.screen = .home
                                state.homeTab = .tree
                                state.showGlobalMenu = false
                            }
                        },
                        onSelectWorkoutHistory: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                state.screen = .workoutHistory
                                state.showGlobalMenu = false
                            }
                        },
                        onSelectAchievements: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                state.screen = .achievements
                                state.showGlobalMenu = false
                            }
                        },
                        onSelectSettings: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                state.screen = .settings
                                state.showGlobalMenu = false
                            }
                        }
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(1)
                }
            }
        }
        .environment(state)
        .onAppear {
            state.requestHealthKitAccessIfNeeded()
        }
        .onReceive(countdownTimer) { _ in
            state.handleCountdownTick()
        }
    }
}

private struct AppSideMenuView: View {
    let onSelectMyTree: () -> Void
    let onSelectWorkoutHistory: () -> Void
    let onSelectAchievements: () -> Void
    let onSelectSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        DrawableImage(path: "potly-icon", fallbackColor: .white)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text("Potly - 組間休息計時")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                    }
                    Divider()
                        .overlay(Color.white.opacity(0.4))
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 4) {
                    menuRow(icon: "leaf.fill",      title: "我的小樹", action: onSelectMyTree)
                    menuRow(icon: "chart.bar.fill", title: "運動紀錄", action: onSelectWorkoutHistory)
                    menuRow(icon: "trophy.fill",    title: "成就達成", action: onSelectAchievements)
                    menuRow(icon: "gearshape.fill", title: "設定", action: onSelectSettings)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }
            .frame(minWidth: 260, maxWidth: 260)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(
                Color(red: 0.44, green: 0.62, blue: 0.58)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 10, x: 4, y: 0)

            Spacer()
        }
    }

    private func menuRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inline screen views for current target

struct AchievementsView: View {
    @Environment(AppState.self) private var state

    private let cardWidth: CGFloat = 320

    private var nextPlant: PlantCatalogEntry? {
        state.nextLockedPlant()
    }

    private var nextRequirement: Int {
        guard let nextPlant else { return 0 }
        return state.unlockRequirement(for: nextPlant.id)
    }

    private var nextProgress: Double {
        guard nextRequirement > 0 else { return 1 }
        return min(Double(state.achievementPoints) / Double(nextRequirement), 1)
    }

    var body: some View {
        ZStack {
            Color(red: 0.44, green: 0.62, blue: 0.58).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            state.showGlobalMenu = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 1) {
                        Text("成就達成")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        Text("積分解鎖花盆")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Spacer()
                        .frame(width: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    AchievementsSummaryCard(
                        unlockedAchievements: state.unlockedAchievementCount,
                        totalAchievements: state.achievementProgressItems.count,
                        points: state.achievementPoints,
                        unlockedPlants: state.unlockedPlantCount,
                        totalPlants: state.plantCatalog.count
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    UnlockRoadmapCard(
                        nextPlantName: nextPlant?.name,
                        nextRequirement: nextRequirement,
                        currentPoints: state.achievementPoints,
                        progress: nextProgress
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 10)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: cardWidth), spacing: 12)], spacing: 12) {
                        ForEach(state.achievementProgressItems) { item in
                            AchievementCardView(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

private struct AchievementsSummaryCard: View {
    let unlockedAchievements: Int
    let totalAchievements: Int
    let points: Int
    let unlockedPlants: Int
    let totalPlants: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本週成就概覽")
                .font(.headline.bold())
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                StatPill(title: "已解鎖成就", value: "\(unlockedAchievements)/\(totalAchievements)")
                StatPill(title: "成就積分", value: "\(points)")
                StatPill(title: "花盆進度", value: "\(unlockedPlants)/\(totalPlants)")
            }
        }
        .padding(14)
        .background(Color(red: 0.31, green: 0.56, blue: 0.52))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct UnlockRoadmapCard: View {
    let nextPlantName: String?
    let nextRequirement: Int
    let currentPoints: Int
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("花盆解鎖路線")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(Color(red: 0.86, green: 0.89, blue: 0.41))
            }

            ProgressTrack(progress: progress, activeColor: Color(red: 0.86, green: 0.89, blue: 0.41))

            if let nextPlantName {
                HStack {
                    roadmapTag(title: "下一盆栽", value: nextPlantName)
                    roadmapTag(title: "還差積分", value: "\(max(0, nextRequirement - currentPoints))")
                }
            } else {
                Text("全部花盆已解鎖")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
        .background(Color(red: 0.31, green: 0.56, blue: 0.52))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }

    private func roadmapTag(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct AchievementCardView: View {
    let item: AchievementProgressItem

    private var accent: Color {
        item.isUnlocked
        ? Color(red: 0.86, green: 0.89, blue: 0.41)
        : Color.white.opacity(0.45)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.90, green: 0.96, blue: 0.92))
                    .frame(width: 56, height: 56)
                Image(systemName: item.definition.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(red: 0.33, green: 0.60, blue: 0.52))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(item.definition.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("+\(item.definition.points)")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.86, green: 0.89, blue: 0.41))
                        .clipShape(Capsule())
                }

                Text(item.definition.subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.84))
                    .lineLimit(1)

                ProgressTrack(progress: item.progress, activeColor: accent)

                HStack {
                    Text(item.progressText)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.88))
                    Spacer()
                    Text(item.isUnlocked ? "已解鎖" : "進行中")
                        .font(.caption2.bold())
                        .foregroundStyle(item.isUnlocked ? Color(red: 0.86, green: 0.89, blue: 0.41) : .white.opacity(0.72))
                }
            }
        }
        .padding(12)
        .background(Color(red: 0.31, green: 0.56, blue: 0.52))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }
}

private struct ProgressTrack: View {
    let progress: Double
    let activeColor: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                Capsule()
                    .fill(activeColor)
                    .frame(width: proxy.size.width * max(0, min(progress, 1)))
            }
        }
        .frame(height: 8)
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var state

    @State private var notificationsOn: Bool = true
    @State private var soundOn: Bool = true

    private let pageBg = Color(red: 0.44, green: 0.62, blue: 0.58)
    private let surface = Color(red: 0.95, green: 0.97, blue: 0.96)
    private let textPrimary = Color(red: 0.14, green: 0.19, blue: 0.17)
    private let textSecondary = Color(red: 0.43, green: 0.48, blue: 0.45)
    private let accent = Color(red: 0.86, green: 0.89, blue: 0.41)
    private let activeGreen = Color(red: 0.22, green: 0.66, blue: 0.46)

    var body: some View {
        ZStack {
            pageBg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            state.showGlobalMenu = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 1) {
                        Text("設定")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        Text("個人偏好")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.78))
                    }

                    Spacer()

                    Spacer()
                        .frame(width: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        SettingsSectionCard(title: "語言", surface: surface) {
                            SettingsInfoRow(
                                icon: "globe.asia.australia.fill",
                                title: "目前語言",
                                subtitle: "目前僅提供單一語言",
                                textPrimary: textPrimary,
                                textSecondary: textSecondary
                            ) {
                                Text("繁體中文")
                                    .font(.caption.bold())
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(accent)
                                    .clipShape(Capsule())
                            }
                        }

                        SettingsSectionCard(title: "一般", surface: surface) {
                            VStack(spacing: 0) {
                                FixedToggleRow(
                                    icon: "bell.badge.fill",
                                    title: "推播通知",
                                    subtitle: "完成訓練與花盆狀態提醒",
                                    isOn: $notificationsOn,
                                    activeColor: activeGreen,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary
                                )

                                Divider()
                                    .overlay(Color.black.opacity(0.08))
                                    .padding(.horizontal, 12)

                                FixedToggleRow(
                                    icon: "speaker.wave.2.fill",
                                    title: "音效",
                                    subtitle: "按鈕與回饋音效",
                                    isOn: $soundOn,
                                    activeColor: activeGreen,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary
                                )
                            }
                        }

                        SettingsSectionCard(title: "關於", surface: surface) {
                            SettingsInfoRow(
                                icon: "info.circle.fill",
                                title: "版本",
                                subtitle: "Potly",
                                textPrimary: textPrimary,
                                textSecondary: textSecondary
                            ) {
                                Text("1.0.0")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(textPrimary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }

                Spacer()
            }
        }
    }
}

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    let surface: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.white.opacity(0.9))

            VStack(spacing: 0) {
                content
            }
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
    }
}

private struct SettingsInfoRow<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let textPrimary: Color
    let textSecondary: Color
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(red: 0.94, green: 0.96, blue: 0.95))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.24, green: 0.62, blue: 0.49))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(textSecondary)
            }

            Spacer()
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

private struct FixedToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let activeColor: Color
    let textPrimary: Color
    let textSecondary: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(red: 0.94, green: 0.96, blue: 0.95))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.24, green: 0.62, blue: 0.49))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(textSecondary)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isOn.toggle()
                }
            } label: {
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? activeColor : Color(white: 0.79))
                        .frame(width: 52, height: 30)
                    Circle()
                        .fill(.white)
                        .frame(width: 24, height: 24)
                        .padding(.horizontal, 3)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

// MARK: - WorkoutHistoryView

private let whBgColor     = Color(red: 0.44, green: 0.62, blue: 0.58)
private let whCardColor   = Color(red: 0.31, green: 0.56, blue: 0.52)
private let whAccentColor = Color(red: 0.86, green: 0.89, blue: 0.41)
private let whAccentGreen = Color(red: 0.18, green: 0.62, blue: 0.43)

@MainActor
struct WorkoutHistoryView: View {
    @Environment(AppState.self) private var state
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @State private var selectedMuscle: String = "全部"
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var showingDeleteAlert = false
    @State private var pendingDelete: WorkoutSession?
    @State private var selectedSessionForDetail: WorkoutSession?
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @Environment(\.modelContext) private var modelContext

    private var muscleGroups: [String] {
        ["全部"] + Array(Set(sessions.map(\.muscleGroup))).sorted()
    }
    private var filteredByMuscle: [WorkoutSession] {
        selectedMuscle == "全部" ? sessions : sessions.filter { $0.muscleGroup == selectedMuscle }
    }

    private var recordsForSelectedDate: [WorkoutSession] {
        let cal = Calendar.current
        return filteredByMuscle.filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var selectedDateText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M 月 d 日"
        return fmt.string(from: selectedDate)
    }

    var body: some View {
        ZStack {
            whBgColor.ignoresSafeArea()
            VStack(spacing: 0) {
                histNavBar.padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 12)
                if sessions.isEmpty {
                    histEmptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            histChartCard
                            histMuscleFilter
                            histSessionList
                        }
                        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 32)
                    }
                }
            }
        }
        .alert("刪除紀錄", isPresented: $showingDeleteAlert, presenting: pendingDelete) { s in
            Button("刪除", role: .destructive) { modelContext.delete(s); try? modelContext.save() }
            Button("取消", role: .cancel) {}
        } message: { s in Text("確定刪除「\(s.exerciseName)」的訓練紀錄？") }
        .sheet(item: $selectedSessionForDetail) { session in
            ExerciseHistoryDetailView(
                exerciseName: session.exerciseName,
                sessions: sessions.filter { $0.exerciseName == session.exerciseName }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareImage {
                ActivityShareSheet(activityItems: [shareImage])
            }
        }
    }

    // MARK: Nav Bar
    private var histNavBar: some View {
        HStack {
            Button { withAnimation(.easeInOut(duration: 0.3)) { state.showGlobalMenu = true } } label: {
                Image(systemName: "line.3.horizontal").font(.title3.bold()).foregroundStyle(.white)
            }.buttonStyle(.plain)
            Spacer()
            Text("運動紀錄").font(.headline.bold()).foregroundStyle(.white)
            Spacer()
            Text("\(recordsForSelectedDate.count) 筆").font(.subheadline).foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: Empty State
    private var histEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.bar.xaxis").font(.system(size: 52)).foregroundStyle(.white.opacity(0.4))
            Text("還沒有訓練紀錄").font(.headline.bold()).foregroundStyle(.white.opacity(0.7))
            Text("完成第一次訓練後紀錄會出現在這裡").font(.subheadline).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
            Spacer()
        }.padding(.horizontal, 40)
    }

    // MARK: Chart Card (含切換)
    private var histChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("近 30 天訓練熱力圖")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
            }

            histHeatmap

            Text("目前顯示：\(selectedDateText)")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.82))
        }
        .padding(16)
        .background(whCardColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: 30-day Heatmap
    private var histHeatmap: some View {
        let data = histMonthData()
        let cal = Calendar.current
        // 週標題
        let weekLabels = ["日", "一", "二", "三", "四", "五", "六"]
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return VStack(alignment: .leading, spacing: 6) {
            // Weekday header
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(weekLabels, id: \.self) { w in
                    Text(w).font(.caption2).foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            // Day cells
            let startWeekday = cal.component(.weekday, from: data.first?.date ?? .now) - 1
            LazyVGrid(columns: cols, spacing: 4) {
                // leading empty cells
                ForEach(0..<startWeekday, id: \.self) { _ in Color.clear.frame(height: 28) }
                // day cells
                ForEach(data, id: \.date) { item in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(heatColor(count: item.count))
                        .frame(height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(
                                    Calendar.current.isDate(item.date, inSameDayAs: selectedDate)
                                    ? Color.white.opacity(0.95)
                                    : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .overlay(
                            item.count > 0
                            ? Text("\(item.count)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            : nil
                        )
                        .onTapGesture {
                            selectedDate = Calendar.current.startOfDay(for: item.date)
                        }
                }
            }

            // Legend
            HStack(spacing: 6) {
                Text("少").font(.caption2).foregroundStyle(.white.opacity(0.5))
                ForEach([0, 1, 2, 3, 4], id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3).fill(heatColor(count: i))
                        .frame(width: 14, height: 14)
                }
                Text("多").font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 4)
        }
    }

    // MARK: Muscle Filter
    private var histMuscleFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(muscleGroups, id: \.self) { group in
                    let sel = selectedMuscle == group
                    Button { withAnimation(.easeInOut(duration: 0.2)) { selectedMuscle = group } } label: {
                        Text(group).font(.subheadline.bold())
                            .foregroundStyle(sel ? whCardColor : .white)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(sel ? whAccentColor : Color.white.opacity(0.18))
                            .clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
            }.padding(.vertical, 2)
        }
    }

    // MARK: Session List
    private var histSessionList: some View {
        VStack(spacing: 12) {
            if recordsForSelectedDate.isEmpty {
                VStack(spacing: 6) {
                    Text("當天沒有訓練紀錄")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.72))
                    Text("點上方趨勢圖可切換其他日期")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(recordsForSelectedDate) { session in
                        HistSessionCard(session: session) {
                            pendingDelete = session; showingDeleteAlert = true
                        } onOpenDetail: {
                            selectedSessionForDetail = session
                        }
                    }
                }
            }

            Button {
                guard let image = generateShareImage() else { return }
                shareImage = image
                showShareSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("分享圖片")
                }
                .font(.subheadline.bold())
                .foregroundStyle(whCardColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(whAccentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(sessions.isEmpty)
            .opacity(sessions.isEmpty ? 0.5 : 1.0)
        }
    }

    // MARK: Data helpers
    private struct DayData { let date: Date; let count: Int }

    private func histMonthData() -> [DayData] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<30).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            return DayData(date: day, count: filteredByMuscle.filter { cal.isDate($0.date, inSameDayAs: day) }.count)
        }
    }

    private func heatColor(count: Int) -> Color {
        switch count {
        case 0:    return Color.white.opacity(0.1)
        case 1:    return whAccentColor.opacity(0.35)
        case 2:    return whAccentColor.opacity(0.6)
        case 3:    return whAccentColor.opacity(0.82)
        default:   return whAccentColor
        }
    }

    @MainActor
    private func generateShareImage() -> UIImage? {
        let data = shareMonthData()
        let renderer = ImageRenderer(
            content: WorkoutHeatmapShareCard(
                days: data,
                todayCalories: state.todayCalories,
                todayWorkoutCount: data.last?.count ?? 0
            )
            .frame(width: 720)
        )
        renderer.scale = 2
        return renderer.uiImage
    }

    private func shareMonthData() -> [ShareHeatDay] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<30).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let count = sessions.filter { cal.isDate($0.date, inSameDayAs: day) }.count
            return ShareHeatDay(date: day, count: count)
        }
    }
}

private struct ShareHeatDay {
    let date: Date
    let count: Int
}

private struct WorkoutHeatmapShareCard: View {
    let days: [ShareHeatDay]
    let todayCalories: Double
    let todayWorkoutCount: Int

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdayLabels = ["日", "一", "二", "三", "四", "五", "六"]

    private var startWeekdayOffset: Int {
        let cal = Calendar.current
        return max(0, cal.component(.weekday, from: days.first?.date ?? .now) - 1)
    }

    private var dateRangeText: String {
        guard let first = days.first?.date, let last = days.last?.date else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        return "\(fmt.string(from: first)) - \(fmt.string(from: last))"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.33, green: 0.56, blue: 0.53),
                    Color(red: 0.27, green: 0.48, blue: 0.47)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Potly 今日分享")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(.white)
                        Text(dateRangeText)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    Spacer()
                    Image(systemName: "flame.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.28))
                }

                HStack(spacing: 10) {
                    shareStatPill("今日消耗量", "\(Int(todayCalories)) kcal")
                    shareStatPill("今日訓練次數", "\(todayWorkoutCount)")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("近 30 天訓練熱力圖")
                        .font(.headline.bold())
                        .foregroundStyle(.white)

                    LazyVGrid(columns: cols, spacing: 6) {
                        ForEach(weekdayLabels, id: \.self) { label in
                            Text(label)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.55))
                                .frame(maxWidth: .infinity)
                        }
                    }

                    LazyVGrid(columns: cols, spacing: 6) {
                        ForEach(0..<startWeekdayOffset, id: \.self) { _ in
                            Color.clear.frame(height: 26)
                        }
                        ForEach(Array(days.enumerated()), id: \.offset) { _, item in
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(shareHeatColor(item.count))
                                .frame(height: 26)
                                .overlay(
                                    item.count > 0
                                    ? Text("\(item.count)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                    : nil
                                )
                        }
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack {
                    Text("用運動，養成更好的自己")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text("#potly")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .padding(24)
        }
        .frame(height: 980)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func shareStatPill(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func shareHeatColor(_ count: Int) -> Color {
        switch count {
        case 0:    return Color.white.opacity(0.08)
        case 1:    return Color(red: 0.77, green: 0.86, blue: 0.46).opacity(0.45)
        case 2:    return Color(red: 0.77, green: 0.86, blue: 0.46).opacity(0.70)
        case 3:    return Color(red: 0.77, green: 0.86, blue: 0.46).opacity(0.88)
        default:   return Color(red: 0.77, green: 0.86, blue: 0.46)
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct HistSessionCard: View {
    let session: WorkoutSession
    let onDelete: () -> Void
    let onOpenDetail: () -> Void
    @State private var expanded = false

    private var dateText: String {
        let fmt = DateFormatter(); fmt.dateFormat = "M/d HH:mm"; return fmt.string(from: session.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onOpenDetail) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(whAccentGreen).frame(width: 42, height: 42)
                            Image(systemName: "dumbbell.fill").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.exerciseName).font(.headline.bold()).foregroundStyle(.white)
                            HStack(spacing: 6) {
                                Text(session.muscleGroup).font(.caption.bold()).foregroundStyle(whAccentColor)
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(whAccentColor.opacity(0.18)).clipShape(Capsule())
                                Text(dateText).font(.caption).foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(session.totalSets) 組").font(.subheadline.bold()).foregroundStyle(.white)
                            Text(String(format: "%.0f kg", session.maxWeight)).font(.caption).foregroundStyle(.white.opacity(0.65))
                        }
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.trailing, 12)
                }
                .buttonStyle(.plain)
            }

            if expanded {
                Divider().overlay(Color.white.opacity(0.15))
                VStack(spacing: 0) {
                    HStack(spacing: 20) {
                        histStatPill(label: "總訓練量", value: String(format: "%.0f kg", session.totalVolume))
                        histStatPill(label: "最大重量", value: String(format: "%.1f kg", session.maxWeight))
                        histStatPill(label: "組數", value: "\(session.sets.count)")
                    }.padding(.horizontal, 14).padding(.vertical, 10)
                    Divider().overlay(Color.white.opacity(0.1))
                    ForEach(session.sets.sorted(by: { $0.setNumber < $1.setNumber })) { set in
                        HStack {
                            Text("第 \(set.setNumber) 組").font(.subheadline).foregroundStyle(.white.opacity(0.65)).frame(width: 60, alignment: .leading)
                            Text(String(format: "%.1f kg", set.weightKg)).font(.subheadline.bold()).foregroundStyle(.white)
                            Spacer()
                            Text("\(set.reps) 下").font(.subheadline).foregroundStyle(.white.opacity(0.75))
                        }.padding(.horizontal, 14).padding(.vertical, 8)
                    }
                    Divider().overlay(Color.white.opacity(0.1))
                    Button(action: onDelete) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                            Text("刪除此紀錄")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 0.86, green: 0.26, blue: 0.24))
                        )
                    }.buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(whCardColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }

    private func histStatPill(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.subheadline.bold()).foregroundStyle(.white)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.55))
        }.frame(maxWidth: .infinity)
    }
}

private struct ExerciseHistoryDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let exerciseName: String
    let sessions: [WorkoutSession]

    private struct TrendPoint: Identifiable {
        let id: UUID
        let date: Date
        let maxWeight: Double
        let volume: Double
        let setCount: Int
    }

    private var orderedSessions: [WorkoutSession] {
        sessions.sorted { $0.date < $1.date }
    }

    private var trend: [TrendPoint] {
        orderedSessions.map {
            TrendPoint(
                id: $0.id,
                date: $0.date,
                maxWeight: $0.maxWeight,
                volume: $0.totalVolume,
                setCount: $0.sets.count
            )
        }
    }

    private var bestWeight: Double {
        trend.map(\.maxWeight).max() ?? 0
    }

    private var averageMaxWeight: Double {
        guard !trend.isEmpty else { return 0 }
        return trend.reduce(0) { $0 + $1.maxWeight } / Double(trend.count)
    }

    private var totalVolume: Double {
        trend.reduce(0) { $0 + $1.volume }
    }

    private var averageReps: Double {
        let allSets = orderedSessions.flatMap(\.sets)
        guard !allSets.isEmpty else { return 0 }
        let totalReps = allSets.reduce(0) { $0 + $1.reps }
        return Double(totalReps) / Double(allSets.count)
    }

    private var latestDateText: String {
        guard let latest = orderedSessions.last else { return "--" }
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d HH:mm"
        return fmt.string(from: latest.date)
    }

    private var yDomain: ClosedRange<Double> {
        guard let minValue = trend.map(\.maxWeight).min(),
              let maxValue = trend.map(\.maxWeight).max() else {
            return 0...100
        }
        if minValue == maxValue {
            let padding = max(5, maxValue * 0.15)
            return max(0, minValue - padding)...(maxValue + padding)
        }
        let padding = max(2, (maxValue - minValue) * 0.2)
        return max(0, minValue - padding)...(maxValue + padding)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                whBgColor.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        statGrid
                        weightTrendCard
                        recentRecordsCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(exerciseName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(whBgColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var statGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                detailStatCard(title: "最佳重量", value: String(format: "%.1f kg", bestWeight))
                detailStatCard(title: "平均重量", value: String(format: "%.1f kg", averageMaxWeight))
            }
            HStack(spacing: 10) {
                detailStatCard(title: "平均次數", value: String(format: "%.1f 下", averageReps))
                detailStatCard(title: "累積總量", value: String(format: "%.0f kg", totalVolume))
            }
            HStack {
                Text("最近一次：\(latestDateText)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                Text("共 \(sessions.count) 次訓練")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.top, 2)
        }
    }

    private var weightTrendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("重量變化趨勢")
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.9))

            if trend.isEmpty {
                Text("目前沒有可顯示的資料")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(trend) { point in
                    AreaMark(
                        x: .value("日期", point.date),
                        y: .value("重量", point.maxWeight)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                whAccentColor.opacity(0.35),
                                whAccentColor.opacity(0.05),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("日期", point.date),
                        y: .value("重量", point.maxWeight)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(whAccentColor)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                    PointMark(
                        x: .value("日期", point.date),
                        y: .value("重量", point.maxWeight)
                    )
                    .foregroundStyle(.white)
                    .symbolSize(46)
                }
                .chartYScale(domain: yDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [3, 3]))
                            .foregroundStyle(Color.white.opacity(0.12))
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [3, 3]))
                            .foregroundStyle(Color.white.opacity(0.12))
                        AxisValueLabel()
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                }
                .chartPlotStyle { plot in
                    plot
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .frame(height: 180)
            }
        }
        .padding(14)
        .background(whCardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var recentRecordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("近期紀錄")
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.9))

            ForEach(Array(trend.reversed().prefix(8))) { item in
                HStack(spacing: 10) {
                    Text(dateText(item.date))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 72, alignment: .leading)

                    Text(String(format: "%.1f kg", item.maxWeight))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 72, alignment: .leading)

                    Text("\(item.setCount) 組")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 42, alignment: .leading)

                    Spacer()

                    Text(String(format: "%.0f kg", item.volume))
                        .font(.caption.bold())
                        .foregroundStyle(whAccentColor)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(whCardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func detailStatCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(whCardColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func dateText(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        return fmt.string(from: date)
    }
}

// MARK: - WorkoutPlanView

struct WorkoutPlanView: View {
    @Environment(AppState.self) private var state
    @State private var showCreateSheet = false
    @State private var editingPlan: WorkoutPlan? = nil

    private let bg    = Color(red: 0.44, green: 0.62, blue: 0.58)
    private let card  = Color(red: 0.31, green: 0.56, blue: 0.52)
    private let accent = Color(red: 0.86, green: 0.89, blue: 0.41)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Nav
                HStack {
                    Button { withAnimation(.easeInOut(duration: 0.3)) { state.screen = .home } } label: {
                        Image(systemName: "chevron.left").font(.headline.bold()).foregroundStyle(.white)
                    }.buttonStyle(.plain)
                    Spacer()
                    Text("訓練菜單").font(.headline.bold()).foregroundStyle(.white)
                    Spacer()
                    Button { showCreateSheet = true } label: {
                        Image(systemName: "plus").font(.headline.bold())
                            .padding(8).background(accent).clipShape(Circle())
                            .foregroundStyle(Color(red: 0.31, green: 0.56, blue: 0.52))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 16)

                if state.workoutPlans.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        DrawableImage(path: "drawable/task", fallbackColor: .white.opacity(0.35))
                            .frame(width: 52, height: 52)
                        Text("還沒有訓練菜單").font(.headline.bold()).foregroundStyle(.white.opacity(0.7))
                        Text("點右上角 + 新增你的第一個菜單").font(.subheadline).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(state.workoutPlans) { plan in
                                PlanCard(plan: plan,
                                    onStart: {
                                        state.startPlan(plan)
                                    },
                                    onEdit: { editingPlan = plan },
                                    onDelete: { state.deletePlan(plan) }
                                )
                            }
                        }
                        .padding(.horizontal, 20).padding(.bottom, 32)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            PlanEditSheet(mode: .create) { state.addPlan($0) }
        }
        .sheet(item: $editingPlan) { plan in
            PlanEditSheet(mode: .edit(plan)) { state.updatePlan($0) }
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: WorkoutPlan
    let onStart: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var expanded = false

    private let card   = Color(red: 0.31, green: 0.56, blue: 0.52)
    private let accent = Color(red: 0.86, green: 0.89, blue: 0.41)
    private let green  = Color(red: 0.18, green: 0.62, blue: 0.43)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(accent.opacity(0.25)).frame(width: 44, height: 44)
                    DrawableImage(path: "drawable/task", fallbackColor: accent)
                        .frame(width: 24, height: 24)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name).font(.headline.bold()).foregroundStyle(.white)
                    Text("\(plan.items.count) 個動作").font(.caption).foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                // Start button
                Button(action: onStart) {
                    Text("開始").font(.subheadline.bold()).foregroundStyle(card)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(accent).clipShape(Capsule())
                }.buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold()).foregroundStyle(.white.opacity(0.5))
                }.buttonStyle(.plain)
            }
            .padding(14)

            if expanded {
                Divider().overlay(Color.white.opacity(0.15))
                VStack(spacing: 0) {
                    ForEach(Array(plan.items.enumerated()), id: \.element.id) { idx, item in
                        HStack {
                            Text("\(idx + 1)").font(.caption.bold()).foregroundStyle(.white.opacity(0.45)).frame(width: 20)
                            Text(item.exerciseName).font(.subheadline).foregroundStyle(.white)
                            Spacer()
                            Text("\(item.sets)組 · \(Int(item.targetWeightKg))kg · \(item.targetReps)下")
                                .font(.caption).foregroundStyle(.white.opacity(0.65))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        if idx < plan.items.count - 1 {
                            Divider().overlay(Color.white.opacity(0.08)).padding(.leading, 44)
                        }
                    }
                    Divider().overlay(Color.white.opacity(0.15))
                    HStack {
                        Button(action: onEdit) {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil")
                                Text("編輯")
                            }
                            .font(.subheadline.bold())
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.12))
                            )
                        }.buttonStyle(.plain)
                        Button(action: onDelete) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                Text("刪除")
                            }
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(red: 0.86, green: 0.26, blue: 0.24))
                            )
                        }.buttonStyle(.plain)
                    }
                    .padding(.vertical, 10).padding(.horizontal, 14)
                }
            }
        }
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }
}

// MARK: - Plan Edit Sheet

private struct PlanEditSheet: View {
    enum Mode { case create; case edit(WorkoutPlan) }

    let mode: Mode
    let onSave: (WorkoutPlan) -> Void

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var planName = ""
    @State private var items: [WorkoutPlanItem] = []
    @State private var showExPicker = false

    private let bg       = Color.white
    private let softGray = Color(white: 0.94)
    private let labelCol = Color(white: 0.35)
    private let green    = Color(red: 0.30, green: 0.56, blue: 0.50)
    private var isEdit: Bool { if case .edit = mode { return true }; return false }
    private var originalID: UUID? { if case .edit(let p) = mode { return p.id }; return nil }
    private var isValid: Bool { !planName.trimmingCharacters(in: .whitespaces).isEmpty && !items.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 名稱
                        VStack(alignment: .leading, spacing: 10) {
                            Text("菜單名稱").font(.subheadline.bold()).foregroundStyle(labelCol)
                            TextField("例：胸背日", text: $planName)
                                .foregroundColor(Color.black)
                                .padding(12).background(softGray)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        // 動作列表
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("動作列表").font(.subheadline.bold()).foregroundStyle(labelCol)
                                Spacer()
                                Button { showExPicker = true } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("加入動作")
                                    }
                                    .font(.subheadline.bold()).foregroundStyle(green)
                                }.buttonStyle(.plain)
                            }
                            if items.isEmpty {
                                Text("尚未加入任何動作").font(.subheadline)
                                    .foregroundStyle(Color(white: 0.6))
                                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                                    .background(softGray)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                                        PlanItemRow(item: item,
                                            onUpdate: { items[idx] = $0 },
                                            onDelete: { items.remove(at: idx) }
                                        )
                                        if idx < items.count - 1 {
                                            Divider().padding(.leading, 16)
                                        }
                                    }
                                }
                                .background(softGray)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }

                        // Save
                        Button {
                            let plan = WorkoutPlan(id: originalID ?? UUID(), name: planName.trimmingCharacters(in: .whitespaces), items: items)
                            onSave(plan); dismiss()
                        } label: {
                            Text(isEdit ? "儲存修改" : "建立菜單")
                                .font(.title3.bold()).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(isValid ? green : Color(white: 0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain).disabled(!isValid)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isEdit ? "編輯菜單" : "新增菜單")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(green)
                }
            }
            .sheet(isPresented: $showExPicker) {
                ExercisePickerSheet { ex in
                    let item = WorkoutPlanItem(exerciseID: ex.id, exerciseName: ex.name,
                                              muscleGroup: ex.muscleGroup, sets: ex.defaultSets)
                    items.append(item)
                }
                .environment(state)
            }
        }
        .onAppear {
            if case .edit(let p) = mode { planName = p.name; items = p.items }
        }
    }
}

// MARK: - Plan Item Row (inline edit)

private struct PlanItemRow: View {
    let item: WorkoutPlanItem
    let onUpdate: (WorkoutPlanItem) -> Void
    let onDelete: () -> Void

    @State private var sets: Int
    @State private var reps: Int
    @State private var weightKg: Double

    private let softGray = Color(white: 0.94)
    private let green    = Color(red: 0.30, green: 0.56, blue: 0.50)

    init(item: WorkoutPlanItem, onUpdate: @escaping (WorkoutPlanItem) -> Void, onDelete: @escaping () -> Void) {
        self.item = item; self.onUpdate = onUpdate; self.onDelete = onDelete
        _sets = State(initialValue: item.sets)
        _reps = State(initialValue: item.targetReps)
        _weightKg = State(initialValue: item.targetWeightKg)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.exerciseName).font(.subheadline.bold()).foregroundStyle(Color.black.opacity(0.85))
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.gray.opacity(0.5))
                }.buttonStyle(.plain)
            }
            HStack(spacing: 16) {
                miniStepper(label: "組", value: $sets, range: 1...10)
                miniStepper(label: "下", value: $reps, range: 1...50)
                miniWeightStepper
            }
        }
        .padding(12)
        .onChange(of: sets) { emit() }
        .onChange(of: reps) { emit() }
        .onChange(of: weightKg) { emit() }
    }

    private func miniStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 6) {
            Button { if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 } } label: {
                Image(systemName: "minus").font(.caption.bold()).frame(width: 24, height: 24)
                    .background(Color(white: 0.88)).clipShape(Circle())
            }.buttonStyle(.plain)
            Text("\(value.wrappedValue)\(label)").font(.caption.bold()).foregroundStyle(Color.black.opacity(0.7)).frame(minWidth: 32)
            Button { if value.wrappedValue < range.upperBound { value.wrappedValue += 1 } } label: {
                Image(systemName: "plus").font(.caption.bold()).frame(width: 24, height: 24)
                    .background(Color(white: 0.88)).clipShape(Circle())
            }.buttonStyle(.plain)
        }
    }

    private var miniWeightStepper: some View {
        HStack(spacing: 6) {
            Button { weightKg = max(0, weightKg - 2.5) } label: {
                Image(systemName: "minus").font(.caption.bold()).frame(width: 24, height: 24)
                    .background(Color(white: 0.88)).clipShape(Circle())
            }.buttonStyle(.plain)
            Text(weightKg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(weightKg))kg" : String(format: "%.1fkg", weightKg))
                .font(.caption.bold()).foregroundStyle(Color.black.opacity(0.7)).frame(minWidth: 40)
            Button { weightKg += 2.5 } label: {
                Image(systemName: "plus").font(.caption.bold()).frame(width: 24, height: 24)
                    .background(Color(white: 0.88)).clipShape(Circle())
            }.buttonStyle(.plain)
        }
    }

    private func emit() {
        var updated = item
        updated = WorkoutPlanItem(id: item.id, exerciseID: item.exerciseID, exerciseName: item.exerciseName,
                                  muscleGroup: item.muscleGroup, sets: sets, targetReps: reps, targetWeightKg: weightKg)
        onUpdate(updated)
    }
}

// MARK: - Exercise Picker Sheet

private struct ExercisePickerSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let onSelect: (Exercise) -> Void
    @State private var search = ""

    private var normalizedSearch: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filtered: [Exercise] {
        let q = search.lowercased().trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? state.exercises : state.exercises.filter { $0.name.lowercased().contains(q) }
    }

    private var canQuickAddFromSearch: Bool {
        guard !normalizedSearch.isEmpty else { return false }
        return !state.exercises.contains {
            $0.name.compare(normalizedSearch, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    private var quickAddExercise: Exercise {
        state.upsertExerciseFromPlan(
            name: normalizedSearch,
            muscleGroup: "自訂",
            defaultSets: 4,
            restSeconds: 90
        )
    }

    private let bg    = Color.white
    private let soft  = Color(white: 0.94)
    private let green = Color(red: 0.30, green: 0.56, blue: 0.50)

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.gray.opacity(0.7))
                        TextField("搜尋或輸入新動作名稱", text: $search).foregroundColor(Color.black).tint(green)
                    }
                    .padding(12).background(soft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 20).padding(.vertical, 12)

                    List {
                        if canQuickAddFromSearch {
                            Button {
                                onSelect(quickAddExercise)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("新增到菜單")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(green)
                                        Text(normalizedSearch)
                                            .font(.headline)
                                            .foregroundStyle(Color.black.opacity(0.85))
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(green)
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(bg)
                        }

                        ForEach(filtered) { ex in
                            Button {
                                onSelect(ex); dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(ex.name).font(.headline).foregroundStyle(Color.black.opacity(0.85))
                                        Text("\(ex.muscleGroup) · \(ex.defaultSets) 組").font(.caption).foregroundStyle(Color.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle").foregroundStyle(green)
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(bg)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("選擇動作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundStyle(green)
                }
            }
        }
    }
}

#Preview { ContentView() }
