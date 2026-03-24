import SwiftUI

// MARK: - HomeView

struct HomeView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack(alignment: .leading) {
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
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        RestTimerToolHeader()
                        QuickStartSection()
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .padding(.top, 28)
                    .padding(.bottom, 110)
                }
                .safeAreaPadding(.top, 6)
            }
        }

    }
}

// MARK: - Rest timer tool (home / tree tab)

private struct RestTimerToolHeader: View {
    var body: some View {
        HStack(alignment: .center) {
            Text("Timer")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "timer.circle.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan.opacity(0.95), .mint.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - QuickStartSection

private struct QuickStartSection: View {
    @Environment(AppState.self) private var state
    @State private var showExercisePicker: Bool = false
    @State private var pickerMode: ExercisePickerMode = .muscleGroups
    @State private var selectedMuscleGroup: String? = nil
    @State private var quickAddExerciseName: String = ""
    @State private var exerciseSearchText: String = ""

    private enum ExercisePickerMode {
        case muscleGroups
        case exercises
    }

    var body: some View {
        focusRestTimerCard
            .sheet(isPresented: $showExercisePicker) {
                NavigationStack {
                    Group {
                        if pickerMode == .muscleGroups {
                            muscleGroupPicker
                        } else {
                            exercisePickerList
                        }
                    }
                    .navigationTitle(pickerMode == .muscleGroups ? "選肌群" : (selectedMuscleGroup ?? "選動作"))
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            if pickerMode == .exercises {
                                Button {
                                    pickerMode = .muscleGroups
                                } label: {
                                    Image(systemName: "chevron.left")
                                }
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完成") { showExercisePicker = false }
                        }
                    }
                }
                .toolbarColorScheme(.dark, for: .navigationBar)
                .preferredColorScheme(.dark)
                .onAppear {
                    pickerMode = .muscleGroups
                    selectedMuscleGroup = nil
                    exerciseSearchText = ""
                }
            }
    }

    private var muscleGroupPicker: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                Text("先選肌群，再快速挑動作")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    state.quickStartActionName = ""
                    state.quickStartExerciseIDRaw = ""
                    showExercisePicker = false
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("不指定動作")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                            Text("只使用組間休息計時")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        Spacer()
                        if state.quickStartSelectedExercise == nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [Color.white.opacity(0.16), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(muscleGroupOptions, id: \.self) { group in
                        Button {
                            selectedMuscleGroup = group
                            pickerMode = .exercises
                        } label: {
                            VStack(spacing: 6) {
                                Text(group)
                                    .font(.title3.bold())
                                Text("選擇")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.68))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 84)
                            .background(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.16), Color.white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .background(
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
        )
    }

    private var exercisePickerList: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.7))
                TextField("搜尋動作", text: $exerciseSearchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                TextField("快速新增動作", text: $quickAddExerciseName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .onSubmit { addExerciseQuickly() }
                Button {
                    addExerciseQuickly()
                } label: {
                    Text("新增")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.18))
                        .clipShape(Capsule())
                }
                .disabled(quickAddExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)

            if filteredExercisesByMuscleGroup.isEmpty {
                Text("此肌群目前沒有動作")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
            } else {
                List {
                    ForEach(filteredExercisesByMuscleGroup) { ex in
                        exerciseListRow(ex)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteExerciseFromPicker(ex)
                                } label: {
                                    Label("刪除", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(
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
        )
    }

    private var focusRestTimerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                setupStepperCard(
                    title: "組數",
                    value: "\(state.quickStartTotalSets)",
                    unit: "組",
                    onMinus: { state.quickStartTotalSets = max(1, state.quickStartTotalSets - 1) },
                    onPlus: { state.quickStartTotalSets = min(20, state.quickStartTotalSets + 1) }
                )
                setupStepperCard(
                    title: "休息",
                    value: "\(state.quickStartRestSeconds)",
                    unit: "秒",
                    onMinus: { state.quickStartRestSeconds = max(10, state.quickStartRestSeconds - 10) },
                    onPlus: { state.quickStartRestSeconds = min(300, state.quickStartRestSeconds + 10) }
                )

                setupStepperCard(
                    title: "重量",
                    value: quickWeightText,
                    unit: "kg",
                    onMinus: { state.quickStartWeightKg = max(0, state.quickStartWeightKg - 2.5) },
                    onPlus: { state.quickStartWeightKg = min(500, state.quickStartWeightKg + 2.5) }
                )

                exerciseCard
            }

            Button {
                state.startFocusedRestTimerWorkout()
            } label: {
                Text("開始")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
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
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var exerciseCard: some View {
        Button {
            showExercisePicker = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("動作")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))

                Spacer(minLength: 10)

                Text(state.quickStartSelectedExercise?.name ?? "選擇")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)

                Spacer(minLength: 10)

                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                    Text("切換")
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(12)
            .frame(height: 176)
            .frame(maxWidth: .infinity)
            .background(tileBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func setupStepperCard(
        title: String,
        value: String,
        unit: String,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.72))

            Spacer(minLength: 8)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(value).font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
                Text(unit)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white.opacity(0.60))
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 12)

            HStack(spacing: 18) {
                Button(action: onMinus) {
                    Image(systemName: "minus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.16))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: onPlus) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.16))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(12)
        .frame(height: 176)
        .frame(maxWidth: .infinity)
        .background(tileBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.05), lineWidth: 1)
        )
    }

    private var tileBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                .white.opacity(0.11),
                .white.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var quickWeightText: String {
        if state.quickStartWeightKg.rounded(.down) == state.quickStartWeightKg {
            return "\(Int(state.quickStartWeightKg))"
        }
        return String(format: "%.1f", state.quickStartWeightKg)
    }

    private var muscleGroupOptions: [String] {
        ["胸", "肩", "腿", "手臂", "背"]
    }

    private var filteredExercisesByMuscleGroup: [Exercise] {
        guard let selectedMuscleGroup else { return [] }
        let list = state.exercises
            .filter { $0.muscleGroup == selectedMuscleGroup }
            .sorted { $0.name < $1.name }
        let keyword = exerciseSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(keyword) }
    }

    private func addExerciseQuickly() {
        let name = quickAddExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let group = selectedMuscleGroup else { return }

        let created = state.upsertExerciseFromPlan(
            name: name,
            muscleGroup: group,
            defaultSets: max(1, state.quickStartTotalSets),
            restSeconds: max(10, state.quickStartRestSeconds)
        )

        state.quickStartExerciseIDRaw = created.id.uuidString
        state.quickStartWeightKg = state.suggestedWeightKg(
            forExerciseName: created.name,
            fallback: created.defaultWeightKg
        )

        quickAddExerciseName = ""
        showExercisePicker = false
    }

    private func exerciseListRow(_ ex: Exercise) -> some View {
        Button {
            state.quickStartActionName = ""
            state.quickStartExerciseIDRaw = ex.id.uuidString
            state.quickStartWeightKg = state.suggestedWeightKg(
                forExerciseName: ex.name,
                fallback: ex.defaultWeightKg
            )
            showExercisePicker = false
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ex.name)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    Text(ex.muscleGroup)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                if state.quickStartSelectedExercise?.id == ex.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(14)
            .background(.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func deleteExerciseFromPicker(_ ex: Exercise) {
        if state.quickStartExerciseIDRaw == ex.id.uuidString {
            state.quickStartExerciseIDRaw = ""
        }
        state.deleteExercise(ex)
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
