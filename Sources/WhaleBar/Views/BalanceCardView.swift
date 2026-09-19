import SwiftUI
import WhaleBarKit

/// 面板：账户余额卡（深海军蓝低饱和渐变主视觉，大字号）
struct BalanceCardView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if !appState.isConfigured {
                guide
            } else if let primary = appState.primaryBalance {
                detail(primary)
            } else if appState.isRefreshing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Text("正在获取余额…")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.85))
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("获取失败，请检查网络或凭据")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.85))
                    refreshButton
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.24, blue: 0.40),
                            Color(red: 0.08, green: 0.16, blue: 0.29),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("🐋")
                .font(.title2)
            Text("DeepSeek 余额")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            if let snapshot = appState.balance {
                HStack(spacing: 4) {
                    Circle()
                        .fill(snapshot.isAvailable ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(snapshot.isAvailable ? "可用" : "余额不足")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.15)))
            }
        }
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("配置 API Key 后\n这里会显示你的 DeepSeek 余额")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.9))
            SettingsLink {
                Label("去配置", systemImage: "key.fill")
                    .font(.callout)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .controlSize(.regular)
        }
    }

    private func detail(_ primary: BalanceInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Format.money(primary.total, currency: primary.currency))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("赠送 \(Format.money(primary.granted, currency: primary.currency)) · 充值 \(Format.money(primary.toppedUp, currency: primary.currency))")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.82))

            let others = appState.balance?.infos.filter { $0.currency != primary.currency } ?? []
            if !others.isEmpty {
                Text("其他：" + others.map { Format.money($0.total, currency: $0.currency) }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.65))
            }

            HStack {
                Text(updatedText)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                refreshButton
            }
        }
    }

    private var updatedText: String {
        if let last = appState.lastUpdated {
            return "最后更新 \(Format.time(last))"
        }
        return "尚未刷新"
    }

    private var refreshButton: some View {
        Button {
            Task { await appState.refreshNow() }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                if appState.isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .disabled(appState.isRefreshing)
    }
}
