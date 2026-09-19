import SwiftUI
import WhaleBarKit

/// 设置窗口：凭据 / 刷新 / 状态栏显示 / 关于
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var settings

    @State private var apiKeyInput = ""
    @State private var apiKeyValidation: ValidationState = .idle

    enum ValidationState: Equatable {
        case idle
        case validating
        case success
        case failure(String)
    }

    var body: some View {
        @Bindable var settings = settings
        Form {
            if !appState.isConfigured {
                onboardingHeader
            }
            credentialsSection
            refreshSection($settings)
            displaySection($settings)
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .onAppear {
            if apiKeyInput.isEmpty { apiKeyInput = appState.currentCredential(.apiKey) ?? "" }
        }
    }

    // MARK: - 首启动引导

    private var onboardingHeader: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("欢迎使用 WhaleBar 🐋")
                    .font(.headline)
                Text("两步开始：\n1. 在 DeepSeek 平台创建 API Key\n2. 粘贴到下方「凭据」并验证保存")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Link("打开 DeepSeek 平台 · API Keys", destination: URL(string: "https://platform.deepseek.com/api_keys")!)
                    .font(.callout)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 凭据

    private var credentialsSection: some View {
        Section("凭据") {
            VStack(alignment: .leading, spacing: 6) {
                Text("DeepSeek API Key")
                    .font(.subheadline)
                HStack(spacing: 8) {
                    SecureField("sk-…", text: $apiKeyInput)
                    Button("验证并保存") {
                        Task { await validateAPIKey() }
                    }
                    .disabled(apiKeyInput.trimmed.isEmpty || apiKeyValidation == .validating)
                }
                validationFooter(apiKeyValidation)
                if appState.isConfigured {
                    HStack {
                        Text("当前：已配置")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("移除", role: .destructive) {
                            appState.removeAPIKey()
                            apiKeyInput = ""
                            apiKeyValidation = .idle
                        }
                        .controlSize(.small)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func validationFooter(_ state: ValidationState) -> some View {
        Group {
            switch state {
            case .idle:
                EmptyView()
            case .validating:
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini)
                    Text("正在验证…").font(.caption).foregroundStyle(.secondary)
                }
            case .success:
                Label("验证成功，已保存", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .failure(let message):
                Label(message, systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func validateAPIKey() async {
        apiKeyValidation = .validating
        let error = await appState.saveAPIKey(apiKeyInput)
        apiKeyValidation = error == nil ? .success : .failure(error?.userMessage ?? "验证失败")
    }

    // MARK: - 刷新 / 显示 / 关于

    private func refreshSection(_ settings: Bindable<AppSettings>) -> some View {
        Section("刷新") {
            Picker("刷新间隔", selection: settings.refreshInterval) {
                ForEach(RefreshInterval.allCases) { interval in
                    Text(interval.displayName).tag(interval)
                }
            }
            LabeledContent("上次更新") {
                if let last = appState.lastUpdated {
                    Text(Format.time(last)).foregroundStyle(.secondary)
                } else {
                    Text("尚未刷新").foregroundStyle(.secondary)
                }
            }
        }
    }

    private func displaySection(_ settings: Bindable<AppSettings>) -> some View {
        Section("状态栏显示") {
            Picker("样式", selection: settings.displayStyle) {
                ForEach(StatusDisplayStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
        }
    }

    private var aboutSection: some View {
        Section("关于") {
            LabeledContent("版本", value: appVersion)
            LabeledContent("数据来源", value: "DeepSeek 官方 API")
            LabeledContent("凭据存储", value: "macOS Keychain")
        }
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return short ?? "0.1.0"
    }
}
