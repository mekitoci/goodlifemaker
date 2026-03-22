import SwiftUI
import UIKit
import Photos

private struct ShareImagePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// 圓形品牌識別（potly.app），用於分享圖卡。
struct PotlyBrandingBadge: View {
    var size: CGFloat = 48

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                Image("potly-icon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size - 8, height: size - 8)
                    .clipShape(Circle())
            }
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.45), lineWidth: 2)
            )

            Text("potly.app")
                .font(.system(size: size > 44 ? 16 : 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .tracking(0.3)
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.28))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Potly, potly dot app")
    }
}

struct ShareHeatItem: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct ShareDietItem: Identifiable {
    let id = UUID()
    let date: Date
    let statusText: String
    let calories: Double
}

private enum ShareCardMetrics {
    static let width: CGFloat = 720
    static let height: CGFloat = 1280 // 9:16
}

private struct SharePreviewPage: View {
    let content: AnyView

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 1)
            let availableHeight = max(proxy.size.height, 1)
            let scale = min(
                availableWidth / ShareCardMetrics.width,
                availableHeight / ShareCardMetrics.height
            )
            let scaledWidth = ShareCardMetrics.width * scale
            let scaledHeight = ShareCardMetrics.height * scale

            ZStack {
                content
                    .frame(width: ShareCardMetrics.width, height: ShareCardMetrics.height)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: scaledWidth, height: scaledHeight, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ShareExportView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let styleTitles: [String]
    let renderPage: (Int) -> AnyView

    @State private var selectedStyle: Int = 0
    @State private var sharePayload: ShareImagePayload?
    @State private var saveHint = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.96).ignoresSafeArea()

                VStack(spacing: 14) {
                    TabView(selection: $selectedStyle) {
                        ForEach(Array(styleTitles.enumerated()), id: \.offset) { idx, _ in
                            SharePreviewPage(content: renderPage(idx))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: 640)

                    HStack(spacing: 8) {
                        ForEach(Array(styleTitles.enumerated()), id: \.offset) { idx, name in
                            Button {
                                selectedStyle = idx
                            } label: {
                                Text(name)
                                    .font(.caption.bold())
                                    .foregroundStyle(selectedStyle == idx ? .black : .white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(selectedStyle == idx ? Color.white : Color.white.opacity(0.14))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            guard let image = makeImage() else {
                                saveHint = "無法產生圖片，請稍後再試"
                                return
                            }
                            saveToPhotoLibrary(image)
                        } label: {
                            Label("儲存到相簿", systemImage: "photo.badge.arrow.down")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            guard let image = makeImage() else {
                                saveHint = "無法產生圖片，請稍後再試"
                                return
                            }
                            sharePayload = ShareImagePayload(image: image)
                        } label: {
                            Label("分享", systemImage: "square.and.arrow.up.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)

                    if !saveHint.isEmpty {
                        Text(saveHint)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.black.opacity(0.92), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $sharePayload) { payload in
                ShareSystemSheet(items: [payload.image])
            }
        }
    }

    @MainActor
    private func makeImage() -> UIImage? {
        let renderer = ImageRenderer(
            content: renderPage(selectedStyle)
                .frame(width: ShareCardMetrics.width, height: ShareCardMetrics.height)
        )
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: ShareCardMetrics.width, height: ShareCardMetrics.height)
        return renderer.uiImage
    }

    private func saveToPhotoLibrary(_ image: UIImage) {
        saveHint = ""
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            performPhotoSave(image)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        performPhotoSave(image)
                    } else {
                        saveHint = "需要相簿權限：設定 → Potly → 照片 → 加入照片"
                    }
                }
            }
        case .denied, .restricted:
            saveHint = "需要相簿權限：設定 → Potly → 照片 → 加入照片"
        @unknown default:
            saveHint = "無法寫入相簿，請檢查權限設定"
        }
    }

    private func performPhotoSave(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    saveHint = "已儲存到相簿"
                } else {
                    saveHint = error?.localizedDescription ?? "儲存失敗，請稍後再試"
                }
            }
        }
    }
}

struct WorkoutRecordShareCard: View {
    let style: Int
    let heatDays: [ShareHeatItem]
    let records: [WorkoutSession]
    let selectedDateText: String
    let todayCalories: Double

    private let week = ["日", "一", "二", "三", "四", "五", "六"]
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    private var startOffset: Int {
        max(0, Calendar.current.component(.weekday, from: heatDays.first?.date ?? .now) - 1)
    }

    private var totalSets: Int {
        records.reduce(0) { $0 + $1.totalSets }
    }

    private var totalVolume: Double {
        records.reduce(0) { $0 + $1.totalVolume }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Spacer()
                Text("運動紀錄")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(records.count) 筆")
                    .font(.title2.bold())
                    .foregroundStyle(.white.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("近 30 天")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    PotlyBrandingBadge(size: 40)
                }
                LazyVGrid(columns: cols, spacing: 7) {
                    ForEach(week, id: \.self) { w in
                        Text(w)
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: cols, spacing: 7) {
                    ForEach(0..<startOffset, id: \.self) { _ in
                        Color.clear.frame(height: 52)
                    }
                    ForEach(heatDays) { day in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(shareHeatColor(day.count))
                            .frame(height: 52)
                            .overlay(day.count > 0 ? Text("\(day.count)").font(.headline.bold()).foregroundStyle(.white) : nil)
                    }
                }

                HStack(spacing: 10) {
                    Text("少").font(.subheadline).foregroundStyle(.white.opacity(0.55))
                    ForEach(1...5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(shareHeatColor(level))
                            .frame(width: 26, height: 26)
                    }
                    Text("多").font(.subheadline).foregroundStyle(.white.opacity(0.55))
                }
                Text("目前顯示：\(selectedDateText)")
                    .font(.title3.bold())
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(18)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 28))

            HStack(spacing: 10) {
                chip("全部", active: true)
                chip("手臂", active: false)
                chip("胸", active: false)
                Spacer()
            }

            VStack(spacing: 12) {
                ForEach(records.prefix(4)) { session in
                    HStack(spacing: 14) {
                        Circle()
                            .fill(Color(red: 0.16, green: 0.75, blue: 0.48))
                            .frame(width: 54, height: 54)
                            .overlay(Image(systemName: "dumbbell.fill").foregroundStyle(.white))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.exerciseName)
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("手臂  \(selectedDateText)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(session.totalSets) 組")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text(String(format: "%.0f kg", session.totalVolume))
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                if records.isEmpty {
                    Text("今天尚無紀錄")
                        .font(.title3.bold())
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.vertical, 20)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 24)
        .frame(width: ShareCardMetrics.width, height: ShareCardMetrics.height)
        .background(backgroundForStyle(style))
    }

    private func chip(_ text: String, active: Bool) -> some View {
        Text(text)
            .font(.title3.bold())
            .foregroundStyle(active ? Color(red: 0.33, green: 0.52, blue: 0.45) : .white)
            .padding(.horizontal, 26)
            .padding(.vertical, 12)
            .background(active ? Color(red: 0.78, green: 0.86, blue: 0.34) : Color.white.opacity(0.17))
            .clipShape(Capsule())
    }

    private func backgroundForStyle(_ style: Int) -> some View {
        Group {
            switch style {
            case 1:
                LinearGradient(colors: [Color(red: 0.26, green: 0.47, blue: 0.57), Color(red: 0.19, green: 0.39, blue: 0.50)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case 2:
                LinearGradient(colors: [Color(red: 0.28, green: 0.55, blue: 0.48), Color(red: 0.18, green: 0.38, blue: 0.35)], startPoint: .top, endPoint: .bottom)
            default:
                LinearGradient(colors: [Color(red: 0.33, green: 0.56, blue: 0.53), Color(red: 0.27, green: 0.48, blue: 0.47)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    private func shareHeatColor(_ count: Int) -> Color {
        switch count {
        case 0: return Color.white.opacity(0.08)
        case 1: return Color(red: 0.77, green: 0.86, blue: 0.46).opacity(0.45)
        case 2: return Color(red: 0.77, green: 0.86, blue: 0.46).opacity(0.70)
        case 3: return Color(red: 0.77, green: 0.86, blue: 0.46).opacity(0.88)
        default: return Color(red: 0.77, green: 0.86, blue: 0.46)
        }
    }
}

struct BodyManagementShareCard: View {
    let style: Int
    let dietDays: [ShareDietItem]
    let today: Double
    let weekAvg: Double
    let monthTotal: Double

    private var barSeries: [ShareDietItem] {
        Array(dietDays.suffix(7))
    }

    private var maxCalories: Double {
        let m = barSeries.map(\.calories).max() ?? 0
        return max(m, 1)
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("體態管理")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                topMetric("今日消耗", "\(Int(today)) kcal")
                topMetric("7日平均", "\(Int(weekAvg)) kcal")
                topMetric("30日累積", "\(Int(monthTotal)) kcal")
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("每週趨勢")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 8) {
                        pill("消耗", active: true)
                        pill("體重", active: false)
                    }
                }
                trendChart
            }
            .padding(18)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 28))

            VStack(alignment: .leading, spacing: 12) {
                Text("近 30 天飲食狀況")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                dietGrid
            }
            .padding(18)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 28))

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .frame(width: ShareCardMetrics.width, height: ShareCardMetrics.height)
        .background(
            LinearGradient(
                colors: style == 1
                    ? [Color(red: 0.31, green: 0.51, blue: 0.58), Color(red: 0.20, green: 0.38, blue: 0.46)]
                    : [Color(red: 0.33, green: 0.56, blue: 0.53), Color(red: 0.27, green: 0.48, blue: 0.47)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var trendChart: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            let w = proxy.size.width
            let points = barSeries.enumerated().map { idx, item in
                CGPoint(
                    x: w * CGFloat(idx) / CGFloat(max(barSeries.count - 1, 1)),
                    y: h - CGFloat(item.calories / maxCalories) * (h - 16) - 8
                )
            }

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.06))
                Path { p in
                    guard let first = points.first else { return }
                    p.move(to: first)
                    for point in points.dropFirst() { p.addLine(to: point) }
                }
                .stroke(Color(red: 0.86, green: 0.89, blue: 0.41), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))

                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .position(point)
                }
            }
        }
        .frame(height: 300)
    }

    private var dietGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)
        return VStack(spacing: 10) {
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { text in
                    Text(text).font(.title3).foregroundStyle(.white.opacity(0.5))
                }
                ForEach(0..<28, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(idx > 24 ? Color(red: 0.77, green: 0.86, blue: 0.46).opacity(0.8) : Color.white.opacity(0.08))
                        .frame(height: 48)
                }
            }
        }
    }

    private func topMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title3).foregroundStyle(.white.opacity(0.75))
            Text(value).font(.system(size: 44, weight: .bold)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func pill(_ text: String, active: Bool) -> some View {
        Text(text)
            .font(.title3.bold())
            .foregroundStyle(active ? Color(red: 0.33, green: 0.52, blue: 0.45) : .white.opacity(0.7))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(active ? Color(red: 0.78, green: 0.86, blue: 0.34) : Color.white.opacity(0.16))
            .clipShape(Capsule())
    }
}

struct PlantOwnedShareCard: View {
    let style: Int
    let plantName: String
    let quote: String
    let calories: Double
    let steps: Int
    let activities: Int
    let imagePath: String

    private var progress: Double { min(1, Double(max(activities, 0)) / 5.0) }
    private let accent = Color(red: 0.78, green: 0.86, blue: 0.34)
    private let trackColor = Color.white.opacity(0.35)

    var body: some View {
        ZStack {
            // 背景
            bgGradient

            VStack(spacing: 0) {

                // ── 頂部品牌 ──────────────────────────────────────────
                HStack {
                    Spacer()
                    PotlyBrandingBadge(size: 40)
                }
                .padding(.bottom, 14)

                // ── 植物名稱 + 花語（置中） ──────────────────────────
                VStack(spacing: 8) {
                    Text(plantName)
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("「\(quote)」")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Spacer(minLength: 24)

                // ── 小圓環 + 植物圖（置中） ──────────────────────────
                ZStack {
                    // 進度軌道
                    Circle()
                        .stroke(trackColor, lineWidth: 14)
                    // 進度弧
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Circle()
                        .fill(accent)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Color.white, lineWidth: 5))
                        .offset(y: -170)
                    // 內圈淡底
                    Circle()
                        .fill(Color.white.opacity(0.95))
                        .padding(20)
                    // 植物圖
                    VStack(spacing: 6) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 64, weight: .black))
                            .foregroundStyle(.black)
                        Text("\(activities)/5")
                            .font(.title2.bold())
                            .foregroundStyle(.black.opacity(0.4))
                        DrawableImage(path: imagePath, fallbackColor: .gray)
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                    }
                }
                .frame(width: 390, height: 390)
                .frame(maxWidth: .infinity)

                Spacer(minLength: 22)

                // ── 解鎖成就條 ───────────────────────────────────────
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2.bold())
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已解鎖此花盆")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        Text("累積 \(activities) / 5 次運動目標")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Text("身體記得你每一次的付出")
                        .font(.headline.bold())
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.bottom, 14)

                HStack(spacing: 12) {
                    burnCard
                    VStack(spacing: 12) {
                        triStat(icon: "figure.walk",  color: accent,   title: "今日步數",    value: "\(steps)",         unit: "")
                        triStat(icon: "bolt.fill",    color: accent,   title: "今日運動次數", value: "\(activities)",    unit: "")
                    }
                }
                .padding(.bottom, 16)

                // ── 品牌 footer ───────────────────────────────────────
                HStack {
                    Text("#potly  #potly.app")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.72))
                    Spacer()
                    Text("Share your growth")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 24)
            .padding(.bottom, 24)
            .frame(width: ShareCardMetrics.width, height: ShareCardMetrics.height)
        }
        .frame(width: ShareCardMetrics.width, height: ShareCardMetrics.height)
    }

    private var bgGradient: some View {
        Group {
            if style == 2 {
                LinearGradient(
                    colors: [Color(red: 0.25, green: 0.46, blue: 0.42), Color(red: 0.17, green: 0.33, blue: 0.30)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            } else if style == 1 {
                LinearGradient(
                    colors: [Color(red: 0.34, green: 0.57, blue: 0.60), Color(red: 0.22, green: 0.42, blue: 0.46)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                LinearGradient(
                    colors: [Color(red: 0.38, green: 0.62, blue: 0.58), Color(red: 0.28, green: 0.50, blue: 0.47)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    private func triStat(icon: String, color: Color, title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2.bold())
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.72))
            }
            Text(value)
                .font(.system(size: 52, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var burnCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                Text("今日消耗")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer(minLength: 6)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("\(Int(calories))")
                    .font(.system(size: 58, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("kcal")
                    .font(.title2.bold())
                    .foregroundStyle(.white.opacity(0.75))
            }
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.32))
                .frame(height: 14)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.65))
                        .frame(width: 120)
                }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .background(Color.white.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ShareSystemSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
