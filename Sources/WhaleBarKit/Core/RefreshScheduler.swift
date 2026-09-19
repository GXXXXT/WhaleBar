import Foundation

/// 周期刷新调度：可配置间隔 + 失败指数退避（封顶 30 分钟）
@MainActor
public final class RefreshScheduler {
    private let appState: AppState
    private let intervalProvider: () -> TimeInterval
    private var task: Task<Void, Never>?

    private static let maxBackoffFactor: TimeInterval = 6

    public init(appState: AppState, intervalProvider: @escaping () -> TimeInterval) {
        self.appState = appState
        self.intervalProvider = intervalProvider
    }

    public func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            await self?.run()
        }
    }

    /// 设置变化 / 系统唤醒时调用：立即刷新并重置周期
    public func restart() {
        task?.cancel()
        task = nil
        start()
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    private func run() async {
        _ = await appState.refreshNow(force: true)
        var backoffFactor: TimeInterval = 1
        while !Task.isCancelled {
            let interval = intervalProvider() * backoffFactor
            guard await sleep(seconds: interval) else { return }
            let success = await appState.refreshNow(force: true)
            if success {
                backoffFactor = 1
            } else if appState.isConfigured {
                backoffFactor = min(max(backoffFactor * 2, 2), Self.maxBackoffFactor)
            }
        }
    }

    private func sleep(seconds: TimeInterval) async -> Bool {
        do {
            try await Task.sleep(for: .seconds(seconds))
            return true
        } catch {
            return false
        }
    }
}
