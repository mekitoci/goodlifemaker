import SwiftUI

struct DictionaryView: View {
    @Environment(AppState.self) private var state
    @State private var searchText: String = ""
    @State private var selectedGroup: String = "全部"

    private let pageBackground = Color.white
    private let softGray = Color(white: 0.94)
    private let borderGray = Color.black.opacity(0.08)
    private let textPrimary = Color.black.opacity(0.85)
    private let textSecondary = Color.gray.opacity(0.85)
    private let brandGreen = Color(red: 0.30, green: 0.56, blue: 0.50)

    private var groupedExercises: [(group: String, exercises: [Exercise])] {
        let dict = Dictionary(grouping: state.exercises, by: \.muscleGroup)
        return dict.keys.sorted().map { group in
            (group: group, exercises: dict[group] ?? [])
        }
    }

    private var groupOptions: [String] {
        ["全部"] + groupedExercises.map { $0.group }
    }

    private var filteredExercises: [Exercise] {
        let base: [Exercise]
        if selectedGroup == "全部" {
            base = state.exercises
        } else {
            base = state.exercises.filter { $0.muscleGroup == selectedGroup }
        }
        guard !searchText.isEmpty else { return base }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.name.lowercased().contains(q) || $0.muscleGroup.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar

            // Search
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.gray.opacity(0.8))
                TextField("搜尋動作", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundColor(textPrimary)
                    .tint(brandGreen)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.gray.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(softGray)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)

            // Group chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(groupOptions, id: \.self) { g in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedGroup = g
                            }
                        } label: {
                            Text(g)
                                .font(.subheadline.bold())
                                .foregroundStyle(selectedGroup == g ? Color.white : Color.black.opacity(0.75))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                                        .fill(selectedGroup == g ? brandGreen : Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                                        .stroke(borderGray, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // Fast list
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(filteredExercises) { exercise in
                        ExerciseQuickCard(exercise: exercise) {
                            state.startExercise(exercise)
                        }
                    }

                    if filteredExercises.isEmpty {
                        VStack(spacing: 8) {
                            Text("找不到符合的動作")
                                .font(.headline.bold())
                                .foregroundStyle(textPrimary)
                            Text("試試看換個關鍵字或分類")
                                .font(.subheadline)
                                .foregroundStyle(textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(pageBackground)
    }

    private var navBar: some View {
        HStack {
            Button { state.screen = .home } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.bold())
                    .padding(10)
                    .background(softGray)
                    .overlay(
                        Circle().stroke(borderGray, lineWidth: 1)
                    )
                    .clipShape(Circle())
                    .foregroundStyle(textPrimary)
            }
            Spacer()
            Text("訓練動作")
                .font(.title2.bold())
                .foregroundStyle(textPrimary)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(pageBackground)
    }

}

private struct ExerciseQuickCard: View {
    let exercise: Exercise
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(white: 0.95))
                        .frame(width: 44, height: 44)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0.30, green: 0.56, blue: 0.50))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(exercise.name)
                            .font(.headline.bold())
                            .foregroundStyle(Color.black.opacity(0.85))
                            .lineLimit(1)
                        Spacer()
                        Text(exercise.muscleGroup)
                            .font(.caption.bold())
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.30, green: 0.56, blue: 0.50).opacity(0.95))
                            .clipShape(Capsule())
                    }

                    Text("\(exercise.defaultSets) 組 · 休息 \(exercise.restSeconds) 秒")
                        .font(.subheadline)
                        .foregroundStyle(Color.gray.opacity(0.85))
                }

                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color(red: 0.30, green: 0.56, blue: 0.50))
                    .clipShape(Circle())
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DictionaryView()
        .environment(AppState())
}
