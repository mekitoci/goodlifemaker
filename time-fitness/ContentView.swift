import SwiftUI
import SwiftData
import Charts
import UIKit

struct ContentView: View {
    @State private var state = AppState()
    @State private var sceneMoveEdge: Edge = .trailing
    @State private var lastSceneOrder: Int = 0
    @State private var hideBottomDock: Bool = false

    private let countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    switch state.screen {
                    case .home:           HomeView()
                    case .dictionary:     DictionaryView()
                    case .workout:        WorkoutView()
                    case .workoutHistory: WorkoutHistoryView()
                    case .bodyManagement: BodyManagementView()
                    case .workoutPlan:    WorkoutPlanView()
                    case .achievements:   AchievementsView()
                    case .settings:       SettingsView()
                    }
                }
                .id("\(state.screen)-\(state.homeTab)")
                .transition(
                    .asymmetric(
                        insertion: .move(edge: sceneMoveEdge).combined(with: .opacity),
                        removal: .move(edge: opposite(of: sceneMoveEdge)).combined(with: .opacity)
                    )
                )
                .animation(.easeInOut(duration: 0.24), value: state.screen)
                .animation(.easeInOut(duration: 0.24), value: state.homeTab)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            // 向上滑（內容往下捲）先收起導覽列，向下滑再顯示
                            if value.translation.height < -10 {
                                if !hideBottomDock {
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        hideBottomDock = true
                                    }
                                }
                            } else if value.translation.height > 10 {
                                if hideBottomDock {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        hideBottomDock = false
                                    }
                                }
                            }
                        }
                        .onEnded { value in
                            // 回到頂部時通常會有下拉手勢，結束後強制顯示導覽列
                            if value.translation.height > 0 {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    hideBottomDock = false
                                }
                            }
                        }
                )
                .toolbar(.hidden, for: .navigationBar)

                if state.screen != .workout {
                    GlobalBottomDock()
                        .padding(.horizontal, 14)
                        .padding(.bottom, 16)
                        .offset(y: hideBottomDock ? 120 : 0)
                        .opacity(hideBottomDock ? 0.0 : 1.0)
                        .allowsHitTesting(!hideBottomDock)
                        .animation(.spring(duration: 0.28, bounce: 0.04), value: hideBottomDock)
                }
            }
        }
        .environment(state)
        .onAppear {
            state.requestHealthKitAccessIfNeeded()
            lastSceneOrder = sceneOrder(screen: state.screen, homeTab: state.homeTab)
        }
        .onReceive(countdownTimer) { _ in
            state.handleCountdownTick()
        }
        .onChange(of: state.screen, initial: false) { _, newValue in
            let next = sceneOrder(screen: newValue, homeTab: state.homeTab)
            sceneMoveEdge = next >= lastSceneOrder ? .trailing : .leading
            lastSceneOrder = next
            hideBottomDock = false
        }
        .onChange(of: state.homeTab, initial: false) { _, newValue in
            let next = sceneOrder(screen: state.screen, homeTab: newValue)
            sceneMoveEdge = next >= lastSceneOrder ? .trailing : .leading
            lastSceneOrder = next
            hideBottomDock = false
        }
    }

    private func sceneOrder(screen: AppScreen, homeTab: HomeTab) -> Int {
        switch screen {
        case .home:
            return 0
        case .workoutHistory:
            return 1
        case .bodyManagement:
            return 3
        case .dictionary:
            return 3
        case .workout:
            return 3
        case .workoutPlan:
            return 3
        case .achievements:
            return 3
        case .settings:
            return 2
        }
    }

    private func opposite(of edge: Edge) -> Edge {
        switch edge {
        case .leading: return .trailing
        case .trailing: return .leading
        case .top: return .bottom
        case .bottom: return .top
        }
    }
}

private struct GlobalBottomDock: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 10) {
            dockIcon("timer", selected: state.screen == .home) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    state.screen = .home
                    state.homeTab = .tree
                }
            }
            dockIcon("chart.bar.fill", selected: state.screen == .workoutHistory) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    state.screen = .workoutHistory
                }
            }
            dockIcon("gearshape.fill", selected: state.screen == .settings) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    state.screen = .settings
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.32))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func dockIcon(_ systemName: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selected ? Color.gray.opacity(0.32) : .clear)
                )
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
                    Spacer()
                        .frame(width: 40)

                    Spacer()

                    VStack(spacing: 1) {
                        Text("成就達成")
                            .font(.headline.bold())
                            .foregroundColor(.white)
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
            Text("成就概覽")
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
    @State private var showAboutAppSheet: Bool = false
    @State private var showCloudSyncSheet: Bool = false

    private let pageBg = Color(red: 0.10, green: 0.16, blue: 0.30)
    private let surface = Color.white.opacity(0.92)
    private let textPrimary = Color(red: 0.12, green: 0.17, blue: 0.26)
    private let textSecondary = Color(red: 0.44, green: 0.49, blue: 0.58)
    private let accent = Color(red: 0.31, green: 0.78, blue: 0.95)
    private let activeGreen = Color(red: 0.44, green: 0.53, blue: 0.98)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.13, blue: 0.24),
                    Color(red: 0.23, green: 0.20, blue: 0.45),
                    Color(red: 0.14, green: 0.42, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                        .frame(width: 40)

                    Spacer()

                    VStack(spacing: 1) {
                        Text("設定")
                            .font(.headline.bold())
                            .foregroundColor(.white)
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
                        SettingsSectionCard(title: "計時器", surface: surface) {
                            VStack(spacing: 0) {
                                FixedToggleRow(
                                    icon: "airpodspro",
                                    title: "耳機音量控制",
                                    subtitle: "",
                                    isOn: Binding(
                                        get: { state.restVolumeControlEnabled },
                                        set: { state.restVolumeControlEnabled = $0 }
                                    ),
                                    activeColor: activeGreen,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary
                                )

                                Divider()
                                    .overlay(Color.black.opacity(0.08))
                                    .padding(.horizontal, 12)

                                SettingsInfoRow(
                                    icon: "list.number",
                                    title: "預設組數",
                                    subtitle: "",
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary
                                ) {
                                    compactAdjustControl(
                                        value: "\(state.quickStartTotalSets)",
                                        onMinus: { state.quickStartTotalSets = max(1, state.quickStartTotalSets - 1) },
                                        onPlus: { state.quickStartTotalSets = min(20, state.quickStartTotalSets + 1) }
                                    )
                                }

                                Divider()
                                    .overlay(Color.black.opacity(0.08))
                                    .padding(.horizontal, 12)

                                SettingsInfoRow(
                                    icon: "list.number",
                                    title: "預設次數",
                                    subtitle: "",
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary
                                ) {
                                    compactAdjustControl(
                                        value: "\(state.selectedReps)",
                                        onMinus: { state.selectedReps = max(1, state.selectedReps - 1) },
                                        onPlus: { state.selectedReps = min(200, state.selectedReps + 1) }
                                    )
                                }

                                Divider()
                                    .overlay(Color.black.opacity(0.08))
                                    .padding(.horizontal, 12)

                                SettingsInfoRow(
                                    icon: "timer",
                                    title: "預設休息",
                                    subtitle: "",
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary
                                ) {
                                    compactAdjustControl(
                                        value: "\(state.quickStartRestSeconds)s",
                                        onMinus: { state.quickStartRestSeconds = max(10, state.quickStartRestSeconds - 10) },
                                        onPlus: { state.quickStartRestSeconds = min(300, state.quickStartRestSeconds + 10) }
                                    )
                                }
                            }
                        }

                        SettingsSectionCard(title: "一般", surface: surface) {
                            VStack(spacing: 0) {
                                FixedToggleRow(
                                    icon: "bell.badge.fill",
                                    title: "通知",
                                    subtitle: "",
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
                                    subtitle: "",
                                    isOn: $soundOn,
                                    activeColor: activeGreen,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary
                                )

                                Divider()
                                    .overlay(Color.black.opacity(0.08))
                                    .padding(.horizontal, 12)

                                SettingsInfoRow(
                                    icon: "info.circle.fill",
                                    title: "版本",
                                    subtitle: "",
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary
                                ) {
                                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(textPrimary)
                                }

                                Divider()
                                    .overlay(Color.black.opacity(0.08))
                                    .padding(.horizontal, 12)

                                Button {
                                    showCloudSyncSheet = true
                                } label: {
                                    SettingsInfoRow(
                                        icon: "icloud.and.arrow.up.fill",
                                        title: "雲端備份",
                                        subtitle: "",
                                        textPrimary: textPrimary,
                                        textSecondary: textSecondary
                                    ) {
                                        Image(systemName: "chevron.right")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(textSecondary.opacity(0.8))
                                    }
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .overlay(Color.black.opacity(0.08))
                                    .padding(.horizontal, 12)

                                Button {
                                    showAboutAppSheet = true
                                } label: {
                                    SettingsInfoRow(
                                        icon: "lock.shield.fill",
                                        title: "隱私權",
                                        subtitle: "",
                                        textPrimary: textPrimary,
                                        textSecondary: textSecondary
                                    ) {
                                        Image(systemName: "chevron.right")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(textSecondary.opacity(0.8))
                                    }
                                }
                                .buttonStyle(.plain)
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
        .sheet(isPresented: $showAboutAppSheet) {
            AboutAppSheet(
                pageBg: pageBg,
                surface: surface,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                accent: accent
            )
        }
        .sheet(isPresented: $showCloudSyncSheet) {
            CloudSyncSheet(
                pageBg: pageBg,
                surface: surface,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                accent: accent
            )
        }
    }

    @ViewBuilder
    private func compactAdjustControl(
        value: String,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Button(action: onMinus) {
                Image(systemName: "minus")
                    .font(.caption.bold())
                    .foregroundStyle(textPrimary)
                    .frame(width: 28, height: 28)
                    .background(Color.black.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(textPrimary)
                .frame(minWidth: 46)

            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.caption.bold())
                    .foregroundStyle(textPrimary)
                    .frame(width: 28, height: 28)
                    .background(Color.black.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct AboutAppSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let pageBg: Color
    let surface: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color

    var body: some View {
        NavigationStack {
            ZStack {
                pageBg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(accent.opacity(0.22))
                                    .frame(width: 42, height: 42)
                                    .overlay(
                                        Image(systemName: "lock.shield.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(accent)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("資料與隱私")
                                        .font(.title3.bold())
                                        .foregroundStyle(.white)
                                    Text("SetRest 的資料只存在你的裝置")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.82))
                                }
                                Spacer()
                            }

                            HStack(spacing: 8) {
                                aboutTag("本機儲存")
                                aboutTag("不追蹤")
                                aboutTag("可手動備份")
                            }

                            Text("我們在本機處理你的訓練資料與 HealthKit 顯示資訊，不會在你未同意下自動上傳雲端。")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            aboutBullet(
                                icon: "internaldrive.fill",
                                title: "資料儲存位置",
                                body: "運動紀錄與設定儲存在本機（SwiftData / UserDefaults）。"
                            )
                            aboutBullet(
                                icon: "heart.text.square.fill",
                                title: "HealthKit 權限範圍",
                                body: "SetRest 只讀取「今日步數」與「今日運動次數」用於畫面顯示，不會回寫。"
                            )
                            aboutBullet(
                                icon: "xmark.shield.fill",
                                title: "我們不會做的事",
                                body: "不販售、不分享、不追蹤你的個人資料。"
                            )
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            Text("如有疑問")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white.opacity(0.94))
                            Text("歡迎寄信聯絡我！")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.78))
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                if let url = URL(string: "mailto:oouuiicc13@gmail.com") {
                                    openURL(url)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "envelope.fill")
                                    Text("聯絡我")
                                }
                                .font(.headline.bold())
                                .foregroundStyle(Color(red: 0.18, green: 0.38, blue: 0.35))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("關於本 App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(pageBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func aboutTag(_ text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.16))
            .clipShape(Capsule())
    }

    private func aboutBullet(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.95))
                )
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
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
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(textSecondary)
                }
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
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(textSecondary)
                }
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

private let whCardColor   = Color.white.opacity(0.10)
private let whAccentColor = Color(red: 0.31, green: 0.78, blue: 0.95)
private let whAccentGreen = Color(red: 0.44, green: 0.53, blue: 0.98)

@MainActor
struct WorkoutHistoryView: View {
    @Environment(AppState.self) private var state
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @State private var selectedMuscle: String = "全部"
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var showingDeleteAlert = false
    @State private var pendingDelete: WorkoutSession?
    @State private var selectedSessionForDetail: WorkoutSession?
    @State private var showShareComposer = false
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
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.13, blue: 0.24),
                    Color(red: 0.23, green: 0.20, blue: 0.45),
                    Color(red: 0.14, green: 0.42, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
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
            Button("刪除", role: .destructive) {
                modelContext.delete(s)
                try? modelContext.save()
                let remaining = sessions.filter { $0.id != s.id }
                state.refreshSummaryStats(from: remaining)
            }
            Button("取消", role: .cancel) {}
        } message: { s in Text("確定刪除「\(s.exerciseName)」的訓練紀錄？") }
        .sheet(item: $selectedSessionForDetail) { session in
            ExerciseHistoryDetailView(
                exerciseName: session.exerciseName,
                sessions: sessions.filter { $0.exerciseName == session.exerciseName }
            )
        }
        .sheet(isPresented: $showShareComposer) {
            ShareExportView(
                title: "分享紀錄",
                styleTitles: ["經典", "卡片", "簡約"],
                renderPage: { style in
                    AnyView(
                        WorkoutRecordShareCard(
                            style: style,
                            heatDays: shareMonthData().map { ShareHeatItem(date: $0.date, count: $0.count) },
                            records: recordsForSelectedDate,
                            selectedDateText: selectedDateText,
                            todayCalories: state.todayTotalCalories
                        )
                    )
                }
            )
        }
    }

    // MARK: Nav Bar
    private var histNavBar: some View {
        HStack {
            Spacer()
                .frame(width: 40)
            Spacer()
            Text("運動紀錄").font(.headline.bold()).foregroundStyle(.white)
            Spacer()
            Text("\(recordsForSelectedDate.count)").font(.subheadline).foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: Empty State
    private var histEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.bar.xaxis").font(.system(size: 52)).foregroundStyle(.white.opacity(0.4))
            Text("還沒有紀錄").font(.headline.bold()).foregroundStyle(.white.opacity(0.72))
            Spacer()
        }.padding(.horizontal, 40)
    }

    // MARK: Chart Card (含切換)
    private var histChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("近 30 天")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Menu {
                    // Button("分享紀錄", systemImage: "square.and.arrow.up") {
                    //     showShareComposer = true
                    // }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            histHeatmap
        }
        .padding(16)
        .background(whCardColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: 30-day Heatmap
    private var histHeatmap: some View {
        let data = histMonthData()
        let cal = Calendar.current
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return VStack(alignment: .leading, spacing: 6) {
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
                                    ? whAccentGreen.opacity(0.95)
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
                            .foregroundStyle(sel ? .white : .white.opacity(0.85))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(sel ? whAccentGreen.opacity(0.98) : Color.white.opacity(0.12))
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
                    Text("當天沒有紀錄")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(Color.white.opacity(0.10))
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
        case 0:    return Color.white.opacity(0.06)
        case 1:    return whAccentGreen.opacity(0.35)
        case 2:    return whAccentGreen.opacity(0.60)
        case 3:    return whAccentGreen.opacity(0.82)
        default:   return whAccentGreen.opacity(0.98)
        }
    }

    @MainActor
    private func generateShareImage() -> UIImage? {
        let data = shareMonthData()
        let renderer = ImageRenderer(
            content: WorkoutHeatmapShareCard(
                days: data,
                todayCalories: state.todayTotalCalories,
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
                        Text("SetRest 今日分享")
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
                    Text("近 30 天")
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
                    Text("#SetRest")
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
        let index: Int
        let dateLabel: String
        let maxWeight: Double
        let volume: Double
        let setCount: Int
    }

    private var orderedSessions: [WorkoutSession] {
        sessions.sorted { $0.date < $1.date }
    }

    private var trend: [TrendPoint] {
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        return orderedSessions.enumerated().map { idx, s in
            TrendPoint(
                id: s.id,
                index: idx + 1,
                dateLabel: fmt.string(from: s.date),
                maxWeight: s.maxWeight,
                volume: s.totalVolume,
                setCount: s.sets.count
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
        let weights = trend.map(\.maxWeight).sorted()
        guard weights.count >= 2 else {
            let v = weights.first ?? 50
            return max(0, v - 10)...(v + 10)
        }
        let q1Idx = weights.count / 4
        let q3Idx = (weights.count * 3) / 4
        let q1 = weights[q1Idx]
        let q3 = weights[q3Idx]
        let iqr = q3 - q1
        let fence = max(iqr * 1.5, 5.0)
        let lo = max(0, q1 - fence)
        let hi = q3 + fence
        let clampedMin = weights.filter { $0 >= lo }.min() ?? lo
        let clampedMax = weights.filter { $0 <= hi }.max() ?? hi
        let padding = max(3, (clampedMax - clampedMin) * 0.18)
        return max(0, clampedMin - padding)...(clampedMax + padding)
    }

    private var yAxisTicks: [Double] {
        let minV = yDomain.lowerBound
        let maxV = yDomain.upperBound
        let step = (maxV - minV) / 3.0
        // Y 軸顯示要「上大下小」，與圖表座標方向一致
        return [0, 1, 2, 3].map { maxV - Double($0) * step }
    }

    /// 以日期類別數判斷是否需要水平滑動（不是看資料總筆數）
    private var trendDateCount: Int {
        Set(trend.map(\.dateLabel)).count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.10, green: 0.16, blue: 0.30).ignoresSafeArea()

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
            .toolbarBackground(Color(red: 0.10, green: 0.16, blue: 0.30), for: .navigationBar)
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
                GeometryReader { geo in
                    let yAxisWidth: CGFloat = 34
                    let gap: CGFloat = 8
                    let visiblePlotWidth = max(120, geo.size.width - yAxisWidth - gap)
                    let contentPlotWidth = max(visiblePlotWidth, CGFloat(trendDateCount) * 64)
                    let needScroll = contentPlotWidth > visiblePlotWidth + 1

                    HStack(spacing: gap) {
                        VStack(spacing: 0) {
                            Text("kg")
                                .font(.caption2.bold())
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.bottom, 2)
                            ForEach(Array(yAxisTicks.enumerated()), id: \.offset) { idx, value in
                                Text(String(format: "%.1f", value))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.62))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                if idx < yAxisTicks.count - 1 { Spacer(minLength: 0) }
                            }
                        }
                        .frame(width: yAxisWidth, height: 180)

                        if needScroll {
                            ScrollView(.horizontal, showsIndicators: false) {
                                trendChart(width: contentPlotWidth)
                            }
                        } else {
                            trendChart(width: visiblePlotWidth)
                        }
                    }
                }
                .frame(height: 180)

                Text("可左右滑動查看較早紀錄")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.52))
            }
        }
        .padding(14)
        .background(whCardColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func trendChart(width: CGFloat) -> some View {
        Chart(trend) { point in
            let clamped = min(max(point.maxWeight, yDomain.lowerBound), yDomain.upperBound)

            ForEach(yAxisTicks, id: \.self) { tick in
                RuleMark(y: .value("YTick", tick))
                    .lineStyle(StrokeStyle(lineWidth: 0.6, dash: [3, 3]))
                    .foregroundStyle(Color.white.opacity(0.12))
            }

            AreaMark(
                x: .value("日期", point.dateLabel),
                y: .value("重量", clamped)
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
                x: .value("日期", point.dateLabel),
                y: .value("重量", clamped)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(whAccentColor)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

            PointMark(
                x: .value("日期", point.dateLabel),
                y: .value("重量", clamped)
            )
            .foregroundStyle(.white)
            .symbolSize(46)
            .annotation(position: .top, spacing: 4) {
                Text(String(format: "%.1f kg", point.maxWeight))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.88))
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(trendDateCount, 6))) { _ in
                AxisValueLabel()
                    .foregroundStyle(Color.white.opacity(0.65))
            }
        }
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(width: width, height: 180)
    }

    private var recentRecordsCard: some View {
        let recent: [TrendPoint] = Array(trend.suffix(8).reversed())
        return VStack(alignment: .leading, spacing: 10) {
            Text("近期紀錄")
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.9))

            ForEach(recent) { item in
                HStack(spacing: 10) {
                    Text(item.dateLabel)
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
