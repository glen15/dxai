import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: DxaiViewModel
    @AppStorage("appLanguage") private var lang = "en"
    private var l: L { L(lang) }

    @State private var nickname: String = DxaiPointService.shared.config.nickname
    @State private var optIn: Bool = DxaiPointService.shared.config.optIn
    @State private var nicknameError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Nickname
            VStack(alignment: .leading, spacing: 6) {
                Text(l.settingsNickname)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    TextField(l.settingsNicknamePlaceholder, text: $nickname)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                        .onChange(of: nickname) { newValue in
                            validateAndSave(newValue)
                        }
                }

                if let error = nicknameError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
            }

            Divider()

            // Opt-in toggle
            VStack(alignment: .leading, spacing: 6) {
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
            }

            Divider()

            // Data preview
            VStack(alignment: .leading, spacing: 6) {
                Text(l.settingsDataPreview)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                let claudeTokens = viewModel.toolStats
                    .filter { $0.tool == "claude" }
                    .reduce(0) { $0 + $1.totalTokens }
                let codexTokens = viewModel.toolStats
                    .filter { $0.tool == "codex" }
                    .reduce(0) { $0 + $1.totalTokens }

                Text(DxaiPointService.shared.submissionPreview(
                    claudeTokens: claudeTokens,
                    codexTokens: codexTokens
                ))
                .font(.system(size: 11, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(6)
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
    }

    private func validateAndSave(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let pattern = "^[a-zA-Z0-9_]{0,16}$"
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else {
            nicknameError = l.settingsNicknameValidation
            return
        }
        if !trimmed.isEmpty && trimmed.count < 2 {
            nicknameError = l.settingsNicknameValidation
            return
        }
        nicknameError = nil
        DxaiPointService.shared.updateNickname(trimmed)
    }
}
