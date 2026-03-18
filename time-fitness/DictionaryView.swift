import SwiftUI

struct DictionaryView: View {
    @Environment(AppState.self) private var state
    @State private var searchText: String = ""
    @State private var selectedGroup: String = "全部"
    @State private var showAddSheet = false
    @State private var editingExercise: Exercise? = nil

    private let pageBackground = Color.white
    private let softGray       = Color(white: 0.94)
    private let borderGray     = Color.black.opacity(0.08)
    private let textPrimary    = Color.black.opacity(0.85)
    private let textSecondary  = Color.gray.opacity(0.85)
    private let brandGreen     = Color(red: 0.30, green: 0.56, blue: 0.50)

    private var groupOptions: [String] {
        ["全部"] + Array(Set(state.exercises.map(\.muscleGroup))).sorted()
    }

    private var filteredExercises: [Exercise] {
        let base = selectedGroup == "全部"
            ? state.exercises
            : state.exercises.filter { $0.muscleGroup == selectedGroup }
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { $0.name.lowercased().contains(q) || $0.muscleGroup.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.gray.opacity(0.8))
                TextField("搜尋動作", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundColor(textPrimary)
                    .tint(brandGreen)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color.gray.opacity(0.8))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(softGray)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)

            // Group chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(groupOptions, id: \.self) { g in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedGroup = g }
                        } label: {
                            Text(g)
                                .font(.subheadline.bold())
                                .foregroundStyle(selectedGroup == g ? .white : Color.black.opacity(0.75))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .fill(selectedGroup == g ? brandGreen : Color.white))
                                .overlay(RoundedRectangle(cornerRadius: 999, style: .continuous)
                                    .stroke(borderGray, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }

            // List with swipe actions
            List {
                ForEach(filteredExercises) { exercise in
                    ExerciseQuickCard(exercise: exercise) {
                        state.startExercise(exercise)
                    }
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            editingExercise = exercise
                        } label: {
                            Label("編輯", systemImage: "pencil")
                        }
                        .tint(brandGreen)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            withAnimation { state.deleteExercise(exercise) }
                        } label: {
                            Label("刪除", systemImage: "trash")
                        }
                    }
                }

                if filteredExercises.isEmpty {
                    VStack(spacing: 8) {
                        Text("找不到符合的動作").font(.headline.bold()).foregroundStyle(textPrimary)
                        Text("試試看換個關鍵字或分類").font(.subheadline).foregroundStyle(textSecondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 28)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(pageBackground)
        }
        .background(pageBackground)
        .sheet(isPresented: $showAddSheet) {
            ExerciseFormSheet(mode: .add) { state.addExercise($0) }
        }
        .sheet(item: $editingExercise) { ex in
            ExerciseFormSheet(mode: .edit(ex)) { state.updateExercise($0) }
        }
    }

    private var navBar: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    state.screen = .home
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.bold()).padding(10)
                    .background(softGray)
                    .overlay(Circle().stroke(borderGray, lineWidth: 1))
                    .clipShape(Circle())
                    .foregroundStyle(textPrimary)
            }
            Spacer()
            Text("訓練動作").font(.title2.bold()).foregroundStyle(textPrimary)
            Spacer()
            Button { showAddSheet = true } label: {
                Image(systemName: "plus")
                    .font(.headline.bold()).padding(10)
                    .background(brandGreen).clipShape(Circle())
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal).padding(.vertical, 12)
        .background(pageBackground)
    }
}

// MARK: - Exercise Quick Card

private struct ExerciseQuickCard: View {
    let exercise: Exercise
    let onStart: () -> Void

    private let brandGreen = Color(red: 0.30, green: 0.56, blue: 0.50)

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(white: 0.95)).frame(width: 44, height: 44)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(brandGreen)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(exercise.name).font(.headline.bold())
                        .foregroundStyle(Color.black.opacity(0.85)).lineLimit(1)
                    Spacer()
                    Text(exercise.muscleGroup).font(.caption.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(brandGreen.opacity(0.95)).clipShape(Capsule())
                }
                Text("\(exercise.defaultSets) 組 · 休息 \(exercise.restSeconds) 秒")
                    .font(.subheadline).foregroundStyle(Color.gray.opacity(0.85))
            }
            Button(action: onStart) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .padding(10).background(brandGreen).clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}

// MARK: - Exercise Form Sheet

private struct ExerciseFormSheet: View {
    enum Mode { case add; case edit(Exercise) }

    let mode: Mode
    let onSave: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name        = ""
    @State private var muscleGroup = ""
    @State private var defaultSets = 4
    @State private var restSeconds = 90

    // Fixed colors — never affected by system appearance
    private let bg         = Color.white
    private let cardBg     = Color(white: 0.97)
    private let softGray   = Color(white: 0.92)
    private let labelColor = Color(white: 0.35)
    private let textColor  = Color.black
    private let brandGreen = Color(red: 0.30, green: 0.56, blue: 0.50)
    private let brandRed   = Color(red: 0.82, green: 0.18, blue: 0.18)
    private let muscleOptions = ["胸", "背", "腿", "肩", "手臂", "核心", "全身"]

    private var isEdit: Bool { if case .edit = mode { return true }; return false }
    private var originalID: UUID? { if case .edit(let ex) = mode { return ex.id }; return nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !muscleGroup.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // 動作名稱
                        formCard(title: "動作名稱") {
                            TextField("例：槓鈴臥推", text: $name)
                                .foregroundColor(textColor)
                                .padding(12)
                                .background(softGray)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        // 肌群
                        formCard(title: "肌群") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                                ForEach(muscleOptions, id: \.self) { g in
                                    let sel = muscleGroup == g
                                    Button { muscleGroup = g } label: {
                                        Text(g)
                                            .font(.subheadline.bold())
                                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                                            .background(sel ? brandGreen : softGray)
                                            .foregroundStyle(sel ? Color.white : textColor)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }.buttonStyle(.plain)
                                }
                            }
                            TextField("或輸入自訂肌群", text: $muscleGroup)
                                .foregroundColor(textColor)
                                .padding(12)
                                .background(softGray)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        // 組數
                        formCard(title: "預設組數") {
                            HStack(spacing: 24) {
                                Button { if defaultSets > 1 { defaultSets -= 1 } } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(textColor)
                                        .frame(width: 44, height: 44)
                                        .background(softGray)
                                        .clipShape(Circle())
                                }.buttonStyle(.plain)
                                Text("\(defaultSets) 組")
                                    .font(.title3.bold()).foregroundStyle(textColor)
                                    .frame(minWidth: 70, alignment: .center)
                                Button { if defaultSets < 10 { defaultSets += 1 } } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(textColor)
                                        .frame(width: 44, height: 44)
                                        .background(softGray)
                                        .clipShape(Circle())
                                }.buttonStyle(.plain)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        // 休息秒數
                        formCard(title: "休息秒數") {
                            HStack(spacing: 10) {
                                ForEach([30, 60, 90, 120], id: \.self) { s in
                                    let sel = restSeconds == s
                                    Button { restSeconds = s } label: {
                                        Text("\(s)s")
                                            .font(.subheadline.bold())
                                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                                            .background(sel ? brandGreen : softGray)
                                            .foregroundStyle(sel ? Color.white : textColor)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }.buttonStyle(.plain)
                                }
                            }
                            HStack(spacing: 16) {
                                Button { if restSeconds > 10 { restSeconds -= 10 } } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(textColor)
                                        .frame(width: 40, height: 40).background(softGray).clipShape(Circle())
                                }.buttonStyle(.plain)
                                Text("自訂：\(restSeconds) 秒")
                                    .font(.subheadline).foregroundStyle(labelColor)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                Button { if restSeconds < 300 { restSeconds += 10 } } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(textColor)
                                        .frame(width: 40, height: 40).background(softGray).clipShape(Circle())
                                }.buttonStyle(.plain)
                            }
                            .padding(.horizontal, 4)
                        }

                        // Save
                        Button {
                            let ex = Exercise(
                                id: originalID ?? UUID(),
                                name: name.trimmingCharacters(in: .whitespaces),
                                muscleGroup: muscleGroup,
                                defaultSets: defaultSets,
                                restSeconds: restSeconds
                            )
                            onSave(ex)
                            dismiss()
                        } label: {
                            Text(isEdit ? "儲存修改" : "新增動作")
                                .font(.title3.bold()).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(isValid ? brandGreen : Color(white: 0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!isValid)
                        .padding(.bottom, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isEdit ? "編輯動作" : "新增動作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(brandGreen)
                }
            }
        }
        .onAppear {
            if case .edit(let ex) = mode {
                name = ex.name; muscleGroup = ex.muscleGroup
                defaultSets = ex.defaultSets; restSeconds = ex.restSeconds
            }
        }
    }

    private func formCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(labelColor)
            content()
        }
        .padding(16)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    DictionaryView().environment(AppState())
}
