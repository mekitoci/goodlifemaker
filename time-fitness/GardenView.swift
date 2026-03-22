import SwiftUI

// MARK: - GardenContentView
// Shown when the "花園" tab is selected on the home screen.
// Displays the full plant encyclopedia in a white card.

struct GardenContentView: View {
    @Environment(AppState.self) private var state
    @State private var searchText: String = ""
    @State private var selectedPlant: PlantCatalogEntry?
    @State private var showDetail: Bool = false

    private var filteredPlants: [PlantCatalogEntry] {
        guard !searchText.isEmpty else { return state.plantCatalog }
        let q = searchText.lowercased()
        return state.plantCatalog.filter {
            $0.name.contains(searchText) || $0.englishName.lowercased().contains(q)
        }
    }

    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        #endif
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────────────
                HStack {
                    Text("我的小樹圖鑑")
                        .font(.title2.bold())
                        .foregroundColor(.black)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            state.screen = .achievements
                        }
                    } label: {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color(red: 0.86, green: 0.67, blue: 0.18))
                            .frame(width: 34, height: 34)
                            .background(Color.black.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 14)

                // ── Search bar ───────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.gray.opacity(0.7))
                    .font(.subheadline)
                TextField("搜尋小樹", text: $searchText)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.gray.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(white: 0.93))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

                // ── Plant grid ───────────────────────────────────────
                ScrollView(showsIndicators: false) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
                        spacing: 18
                    ) {
                        ForEach(filteredPlants) { plant in
                            let count = state.plantCount(for: plant.id)
                            let unlocked = state.isPlantUnlocked(plant.id)
                            PlantGridCell(
                                plant: plant,
                                count: count,
                                isUnlocked: unlocked
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    selectedPlant = plant
                                    showDetail = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        dismissKeyboard()
                    }
                )
            }

            if let plant = selectedPlant, showDetail {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .transition(.opacity)

                PlantDetailSheet(
                    plant: plant,
                    onClose: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            showDetail = false
                        }
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .clipShape(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }
}

// MARK: - PlantGridCell

private struct PlantGridCell: View {
    let plant: PlantCatalogEntry
    let count: Int
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 4) {
            // Image area with optional lock badge
            ZStack(alignment: .topTrailing) {
                DrawableImage(
                    path: isUnlocked ? plant.imagePath : plant.lockImagePath,
                    fallbackColor: isUnlocked ? .green : .gray
                )
                .frame(width: 62, height: 62)
                .saturation(isUnlocked ? 1 : 0)  // Extra safety: desaturate if using fallback

            }

            Text(plant.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.black.opacity(0.78))
                .lineLimit(1)

            Text("x\(count)")
                .font(.system(size: 10))
                .foregroundStyle(Color.gray.opacity(0.65))
        }
    }
}

// MARK: - PlantDetailSheet

private struct PlantDetailSheet: View {
    let plant: PlantCatalogEntry
    let onClose: () -> Void
    
    @Environment(AppState.self) private var state
    @State private var showShareComposer: Bool = false

    private var statusText: String {
        state.plantSelectHint(for: plant)
    }
    
    var body: some View {
        VStack(spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    DrawableImage(path: plant.imagePath, fallbackColor: .green)
                        .frame(width: 78, height: 78)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Spacer(minLength: 0)
                        Text(plant.name)
                            .font(.title3.bold())
                            .foregroundStyle(.black)
                        Text(plant.englishName)
                            .font(.callout)
                            .foregroundStyle(Color(red: 0.55, green: 0.46, blue: 0.29))
                        Spacer(minLength: 0)
                    }
                    .frame(height: 78, alignment: .center)
                    
                    Spacer()
                    
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.gray)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("花語")
                            .font(.caption.bold())
                            .foregroundStyle(.gray.opacity(0.9))
                        Text("「\(plant.quote)」")
                            .font(.headline.bold())
                            .foregroundStyle(Color(red: 0.38, green: 0.47, blue: 0.35))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.88, green: 0.95, blue: 0.86))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    HStack(spacing: 8) {
                        metricPill(title: "目標", value: "\(state.wateringGoalSets(for: plant.id)) 次動作")
                        metricPill(title: "完成", value: "\(state.plantCount(for: plant.id)) 次")
                    }

                    simpleRow(
                        icon: state.isPlantUnlocked(plant.id) ? "lock.open.fill" : "lock.fill",
                        title: "解鎖條件",
                        value: state.isPlantUnlocked(plant.id)
                            ? "已解鎖"
                            : "成就積分 \(state.unlockRequirement(for: plant.id))（目前 \(state.achievementPoints)）",
                        tint: state.isPlantUnlocked(plant.id)
                            ? Color(red: 0.23, green: 0.67, blue: 0.47)
                            : Color.gray
                    )
                }
                .padding(14)
                .background(Color(white: 0.94))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                let canPick = state.canChoosePlant(plant)
                Button {
                    if state.choosePlant(plant) { onClose() }
                } label: {
                    Text(canPick ? "開始栽培" : "目前不可切換")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canPick ? Color(red: 0.85, green: 0.92, blue: 0.55) : Color(white: 0.86))
                        .foregroundStyle(canPick ? .black : .gray)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(!canPick)

                // if state.isPlantUnlocked(plant.id) {
                //     Button {
                //         showShareComposer = true
                //     } label: {
                //         Label("分享已擁有花盆", systemImage: "square.and.arrow.up")
                //             .font(.subheadline.bold())
                //             .frame(maxWidth: .infinity)
                //             .padding(.vertical, 12)
                //             .background(Color.black.opacity(0.06))
                //             .foregroundStyle(.black.opacity(0.75))
                //             .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                //     }
                //     .buttonStyle(.plain)
                // }
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(.horizontal, 24)
            .sheet(isPresented: $showShareComposer) {
                ShareExportView(
                    title: "花盆分享",
                    styleTitles: ["經典", "卡片", "簡約"],
                    renderPage: { style in
                        AnyView(
                            PlantOwnedShareCard(
                                style: style,
                                plantName: plant.name,
                                quote: plant.quote,
                                calories: state.todayTotalCalories,
                                steps: state.todayStepCount,
                                activities: state.todayActivityCount,
                                imagePath: plant.imagePath
                            )
                        )
                    }
                )
            }
    }
    
    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.gray.opacity(0.85))
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.gray)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func simpleRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.gray.opacity(0.9))
                Text(value)
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    ZStack {
        Color(red: 0.44, green: 0.62, blue: 0.58).ignoresSafeArea()
        GardenContentView()
            .padding(.top, 8)
    }
    .environment(AppState())
}
