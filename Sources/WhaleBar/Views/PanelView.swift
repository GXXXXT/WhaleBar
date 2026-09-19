import SwiftUI
import WhaleBarKit

/// 下拉面板主体
struct PanelView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = bannerError {
                ErrorBannerView(error: error)
            }
            BalanceCardView()
            bottomBar
        }
        .padding(12)
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
        .containerBackground(.thickMaterial, for: .window)
        .task {
            await appState.refreshIfStale(maxAge: settings.refreshInterval.seconds)
        }
    }

    /// 横幅错误：未配置不算错误（卡片内引导），仅展示运行期错误
    private var bannerError: AppError? {
        if let balanceError = appState.balanceError, balanceError != .notConfigured {
            return balanceError
        }
        return nil
    }

    private var bottomBar: some View {
        HStack(spacing: 18) {
            SettingsLink {
                Label("设置", systemImage: "gearshape.fill")
            }
            .buttonStyle(.plain)

            Spacer()

            Link(destination: URL(string: "https://platform.deepseek.com/")!) {
                Label("控制台", systemImage: "arrow.up.right")
            }
            .buttonStyle(.plain)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
            }
            .buttonStyle(.plain)
        }
        .font(.body)
        .foregroundStyle(.secondary)
    }
}
