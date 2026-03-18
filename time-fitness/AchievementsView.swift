import SwiftUI

struct AchievementsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            Color(red: 0.44, green: 0.62, blue: 0.58).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            state.screen = .home
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("成就達成")
                        .font(.headline.bold())
                        .foregroundColor(.white)

                    Spacer()

                    Spacer()
                        .frame(width: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        AchievementCardView(
                            title: "栽種盆栽",
                            subtitle: "情緒指數改善 10 次",
                            progressText: "10/10",
                            progress: 1.0,
                            imageName: "seedling"
                        )
                        AchievementCardView(
                            title: "建立花園",
                            subtitle: "情緒指數改善 30 次",
                            progressText: "12/30",
                            progress: 0.4,
                            imageName: "leaf"
                        )
                        AchievementCardView(
                            title: "園藝師",
                            subtitle: "解鎖 5 種小樹",
                            progressText: "2/5",
                            progress: 0.4,
                            imageName: "tree"
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

private struct AchievementCardView: View {
    let title: String
    let subtitle: String
    let progressText: String
    let progress: CGFloat
    let imageName: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.90, green: 0.96, blue: 0.92))
                    .frame(width: 64, height: 64)
                Image(systemName: imageName)
                    .font(.system(size: 26))
                    .foregroundStyle(Color(red: 0.33, green: 0.60, blue: 0.52))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color(red: 0.86, green: 0.89, blue: 0.41))
                        .frame(width: 180 * progress, height: 8)
                }

                HStack {
                    Spacer()
                    Text(progressText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.31, green: 0.56, blue: 0.52))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }
}

