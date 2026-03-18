import SwiftUI

// MARK: - HomeView

struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var isMenuOpen: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            Color(red: 0.44, green: 0.62, blue: 0.58).ignoresSafeArea()

            VStack(spacing: 0) {
                HomeTopBar(onMenuTapped: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isMenuOpen.toggle()
                    }
                })
                .padding(.horizontal, 24)
                .padding(.top, 10)

                ZStack {
                    if state.homeTab == .tree {
                        VStack(spacing: 0) {
                            VStack(spacing: 18) {
                                PlantNameRow()
                                PlantRingCard()
                                Text("總訓練組數：\(state.totalSetsCompleted) 組")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 14)

                            Spacer()

                            QuickStartSection()
                                .padding(.horizontal, 20)
                                .padding(.bottom, 36)
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
                                .padding(.bottom, 30)
                        }
                        .transition(
                            .move(edge: .trailing)
                                .combined(with: .opacity)
                        )
                    }
                }
            }
            .animation(.easeInOut(duration: 0.35), value: state.homeTab)

            if isMenuOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMenuOpen = false
                        }
                    }

                SideMenuView(
                    onSelectMyTree: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            state.screen = .home
                            state.homeTab = .tree
                            isMenuOpen = false
                        }
                    },
                    onSelectAchievements: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            state.screen = .achievements
                            isMenuOpen = false
                        }
                    },
                    onSelectSettings: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            state.screen = .settings
                            isMenuOpen = false
                        }
                    },
                    onLogout: {
                        // placeholder: just close for now
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMenuOpen = false
                        }
                    }
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
                .zIndex(1)
            }
        }
    }
}

// MARK: - HomeTopBar

private struct HomeTopBar: View {
    @Environment(AppState.self) private var state
    let onMenuTapped: () -> Void

    var body: some View {
        HStack {
            Button(action: onMenuTapped) {
                Image(systemName: "line.3.horizontal")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        state.homeTab = .tree
                    }
                } label: {
                    Text("小樹")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black.opacity(state.homeTab == .tree ? 0.85 : 0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        state.homeTab = .garden
                    }
                } label: {
                    Text("花園")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black.opacity(state.homeTab == .garden ? 0.85 : 0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(width: 160)
            .background(.white.opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)

            Spacer()

            Circle()
                .fill(Color.orange.opacity(0.9))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "pawprint.fill")
                        .foregroundStyle(.white)
                        .font(.subheadline)
                )
        }
    }
}

// MARK: - PlantNameRow

private struct PlantNameRow: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 10) {
            // Top badges row
            HStack {
                statusBadge
                Spacer()
                hydrationBadge
            }
            
            // Plant name centered
            Text(state.currentPlant.name)
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(.white.opacity(0.96))
                .shadow(color: .black.opacity(0.2), radius: 2, y: 2)
                .frame(maxWidth: .infinity)
            
            // Quote centered under the name
            Text("「\(state.currentPlant.quote)」")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    private var statusBadge: some View {
        VStack(spacing: 5) {
            Image(systemName: state.hasWorkoutToday
                  ? "checkmark.circle.fill"
                  : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(state.hasWorkoutToday ? Color.green : Color.yellow)
            Text(state.hasWorkoutToday ? "今日已練" : "待運動")
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: 60)
    }

    private var hydrationBadge: some View {
        VStack(spacing: 5) {
            Image(systemName: "drop.fill")
                .font(.title3)
                .foregroundStyle(.cyan)
            Text("\(Int(state.plantHydration))%")
                .font(.caption2.bold())
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: 60)
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
            let angle = state.ringProgress * 2 * Double.pi - Double.pi / 2
            Circle()
                .fill(Color(red: 0.84, green: 0.90, blue: 0.25))
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .offset(x: 124 * cos(angle), y: 124 * sin(angle))
                .animation(.easeInOut(duration: 0.8), value: state.ringProgress)
        }
    }

    private var ringContent: some View {
        VStack(spacing: 4) {
            Text("\(Int(state.plantHydration))%")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(.black)

            Text("\(state.hydrationLevel)/\(state.currentPlant.unlockTarget)")
                .font(.title3.bold())
                .foregroundStyle(.gray)

            ZStack(alignment: .top) {
                DrawableImage(path: state.currentPlant.imagePath, fallbackColor: state.plantColor)
                    .frame(width: 118, height: 118)
                    .scaleEffect(state.plantScale)
                    .animation(.spring(duration: 0.5, bounce: 0.4), value: state.plantScale)

                if state.waterDropVisible {
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
            .padding(.top, 2)
        }
    }
}

// MARK: - QuickStartSection

private struct QuickStartSection: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 12) {
            if let last = state.quickStartExercise {
                quickStartCard(for: last)
            }
            changeMoveButton
        }
    }

    private func quickStartCard(for exercise: Exercise) -> some View {
        Button { state.startExercise(exercise) } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("繼續上次")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.65))
                    Text(exercise.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("\(exercise.defaultSets) 組 · \(Int(state.lastWeight)) kg · 上次 \(state.lastReps) 下")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Text("Start")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(.white.opacity(0.25))
                    .clipShape(Capsule())
            }
            .padding(18)
            .background(Color(red: 0.30, green: 0.56, blue: 0.50))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var changeMoveButton: some View {
        Button { state.screen = .dictionary } label: {
            HStack {
                Image(systemName: "plus.circle.fill").font(.title3)
                Text("換個動作").font(.headline.bold())
                Spacer()
                Image(systemName: "chevron.right").font(.subheadline)
            }
            .foregroundStyle(.white.opacity(0.88))
            .padding(16)
            .background(.white.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SideMenuView

private struct SideMenuView: View {
    let onSelectMyTree: () -> Void
    let onSelectAchievements: () -> Void
    let onSelectSettings: () -> Void
    let onLogout: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "pawprint.fill")
                                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.35))
                                    .font(.system(size: 16, weight: .bold))
                            )
                        Text("Hi Steven")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                    }
                    Divider()
                        .overlay(Color.white.opacity(0.4))
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 20) {
                    menuRow(icon: "tree.fill", title: "我的小樹", action: onSelectMyTree)
                    menuRow(icon: "trophy.fill", title: "成就達成", action: onSelectAchievements)
                    menuRow(icon: "gearshape.fill", title: "設定", action: onSelectSettings)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                Button(action: onLogout) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("登出")
                    }
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.36, green: 0.55, blue: 0.50).opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
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
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                Spacer()
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
