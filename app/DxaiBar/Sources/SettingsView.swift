import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject var viewModel: DxaiViewModel
    @AppStorage("appLanguage") private var lang = "en"
    private var l: L { L(lang) }

    @State private var nickname: String = DxaiPointService.shared.config.nickname
    @State private var optIn: Bool = DxaiPointService.shared.config.optIn
    @State private var nicknameError: String?
    @State private var nicknameSuccess: String?
    @State private var isSaving = false
    @State private var notificationsEnabled = true

    private var nicknameChanged: Bool {
        nickname.trimmingCharacters(in: .whitespaces) != DxaiPointService.shared.config.nickname
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Nickname
            VStack(alignment: .leading, spacing: 6) {
                Text(l.settingsNickname)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(l.settingsNicknamePrivacy)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    TextField(l.settingsNicknamePlaceholder, text: $nickname)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                        .onChange(of: nickname) { _ in
                            nicknameError = nil
                            nicknameSuccess = nil
                        }

                    Button(action: saveNickname) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 40)
                        } else {
                            Text(lang == "ko" ? "저장" : "Save")
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 40)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(!nicknameChanged || isSaving)
                }

                if let error = nicknameError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
                if let success = nicknameSuccess {
                    Text(success)
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
            }

            Divider()

            // Opt-in toggle + Ranking link
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Toggle(isOn: $optIn) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l.settingsOptIn)
                                .font(.system(size: 13, weight: .semibold))
                            Text(l.settingsOptInDesc)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .onChange(of: optIn) { newValue in
                        DxaiPointService.shared.updateOptIn(newValue)
                    }

                    Button(action: {
                        if let url = URL(string: "https://vanguard.dx-ai.cloud") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 9))
                            Text(l.leaderboard)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.yellow.opacity(0.1))
                        .foregroundColor(.yellow)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help(lang == "ko" ? "랭킹 페이지 열기" : "Open ranking page")
                }
            }

            Divider()

            // Notification status
            if !notificationsEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text(lang == "ko" ? "알림이 꺼져 있습니다" : "Notifications are off")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                    Spacer()
                    Button(lang == "ko" ? "설정 열기" : "Open Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.borderless)
                }

                Divider()
            }

            // Not collected
            VStack(alignment: .leading, spacing: 4) {
                Text(l.settingsNotCollected)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.red.opacity(0.7))

                ForEach(l.settingsNotCollectedItems, id: \.self) { item in
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.red.opacity(0.5))
                        Text(item)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear { checkNotificationStatus() }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }

    private func saveNickname() {
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        let pattern = "^[a-zA-Z0-9_]{2,16}$"
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else {
            nicknameError = l.settingsNicknameValidation
            return
        }

        isSaving = true
        nicknameError = nil
        nicknameSuccess = nil

        DxaiPointService.shared.checkNickname(trimmed) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .available:
                    DxaiPointService.shared.updateNickname(trimmed)
                    nicknameSuccess = lang == "ko" ? "저장되었습니다" : "Saved"
                case .taken:
                    nicknameError = lang == "ko" ? "이미 사용 중인 닉네임입니다" : "Nickname already taken"
                case .error(let msg):
                    nicknameError = msg
                }
            }
        }
    }
}
