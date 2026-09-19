import SwiftUI
import WhaleBarKit

/// 菜单栏 label：🐋 + 余额数字
struct StatusLabelView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppSettings.self) private var settings

    var body: some View {
        switch settings.displayStyle {
        case .iconOnly:
            Text("🐋")
        case .numberOnly:
            Text(numberText)
        case .iconAndNumber:
            Text("🐋 \(numberText)")
        }
    }

    private var numberText: String {
        guard appState.isConfigured else { return "开始使用" }
        if let primary = appState.primaryBalance {
            return Format.money(primary.total, currency: primary.currency)
        }
        return "…"
    }
}
