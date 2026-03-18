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
                Text("我的小樹圖鑑")
                    .font(.title2.bold())
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
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
                            PlantGridCell(
                                plant: plant,
                                count: count
                            )
                            .onTapGesture {
                                guard count > 0 else { return }
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

    private var isUnlocked: Bool { count > 0 }

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

                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3.5)
                        .background(Color(white: 0.35).opacity(0.85))
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
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
    
    var body: some View {
        VStack(spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    DrawableImage(path: plant.imagePath, fallbackColor: .green)
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(plant.name)
                            .font(.title2.bold())
                            .foregroundStyle(.black)
                        Text(plant.englishName)
                            .font(.subheadline)
                            .foregroundStyle(Color(red: 0.55, green: 0.46, blue: 0.29))
                        
                        Text("常綠藤本植物")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.85))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    
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
                
                VStack(alignment: .leading, spacing: 10) {
                    infoRow(
                        systemImage: "flower",
                        text: "花語：\(plant.quote)"
                    )
                    infoRow(
                        systemImage: "wateringcan.fill",
                        text: "種植成功需改善：\(plant.unlockTarget) 次"
                    )
                    infoRow(
                        systemImage: "person.fill.checkmark",
                        text: "解鎖需個人改善次數：0 次"
                    )
                }
                .padding(14)
                .background(Color(white: 0.94))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                Button {
                    state.choosePlant(plant)
                    onClose()
                } label: {
                    Text("開始栽培")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.85, green: 0.92, blue: 0.55))
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(.horizontal, 24)
    }
    
    private func infoRow(systemImage: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundStyle(Color.gray)
                .frame(width: 22)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.leading)
        }
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
