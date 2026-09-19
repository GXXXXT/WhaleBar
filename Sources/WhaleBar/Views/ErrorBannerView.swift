import SwiftUI
import WhaleBarKit

/// 面板顶部错误横幅
struct ErrorBannerView: View {
    let error: AppError

    private var severe: Bool {
        if case .invalidAPIKey = error { return true }
        if case .server = error { return true }
        return false
    }

    private var icon: String {
        switch error {
        case .invalidAPIKey: return "key.slash"
        case .network: return "wifi.exclamationmark"
        case .rateLimited: return "tortoise"
        case .decoding: return "curlybraces.square"
        default: return "exclamationmark.triangle"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(severe ? Color.red : Color.orange)
            Text(error.userMessage)
                .font(.callout)
                .lineLimit(2)
            Spacer(minLength: 0)
            if case .invalidAPIKey = error {
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(severe ? Color.red.opacity(0.10) : Color.orange.opacity(0.12))
        )
    }
}
