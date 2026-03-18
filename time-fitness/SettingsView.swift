import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var state

    @State private var selectedLanguage: Int = 0
    @State private var notificationsOn: Bool = true
    @State private var soundOn: Bool = true

    var body: some View {
        ZStack {
            Color(red: 0.44, green: 0.62, blue: 0.58).ignoresSafeArea()

            VStack(spacing: 0) {
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

                    Text("設定")
                        .font(.headline.bold())
                        .foregroundColor(.white)

                    Spacer()

                    Spacer()
                        .frame(width: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 12)

                VStack(spacing: 16) {
                    SettingsSection(title: "語言") {
                        Picker("語言", selection: $selectedLanguage) {
                            Text("繁體中文").tag(0)
                            Text("English").tag(1)
                        }
                        .pickerStyle(.segmented)
                    }

                    SettingsSection(title: "一般") {
                        Toggle(isOn: $notificationsOn) {
                            Text("推播通知")
                        }
                        Toggle(isOn: $soundOn) {
                            Text("音效")
                        }
                    }

                    SettingsSection(title: "關於") {
                        HStack {
                            Text("版本")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()
            }
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.white.opacity(0.9))

            VStack(spacing: 10) {
                content
                    .tint(Color(red: 0.86, green: 0.89, blue: 0.41))
            }
            .padding(14)
            .background(Color(red: 0.31, green: 0.56, blue: 0.52))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        }
    }
}

