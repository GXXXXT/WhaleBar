import Foundation
import Observation

/// 全局应用状态（唯一可变状态收敛点）
/// v0.3 起：仅保留官方 API 余额链路，用量明细功能已移除
@MainActor
@Observable
public final class AppState {
    // MARK: - 依赖

    private let credentials: any CredentialStoring
    private let cache: CacheStore
    private let balanceClient: DeepSeekBalanceClient
    private let now: @Sendable () -> Date

    // MARK: - 可观察状态

    public private(set) var balance: BalanceSnapshot?
    public private(set) var lastUpdated: Date?
    public private(set) var balanceError: AppError?
    public private(set) var isRefreshing = false

    private var throttle = RefreshThrottle(minimumInterval: 5)

    // MARK: - 初始化

    public init(
        credentials: any CredentialStoring = KeychainStore.standard,
        cache: CacheStore = .standard,
        balanceClient: DeepSeekBalanceClient = .live(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.credentials = credentials
        self.cache = cache
        self.balanceClient = balanceClient
        self.now = now
    }

    // MARK: - 派生状态

    public var isConfigured: Bool { credentials.read(.apiKey)?.trimmed.nonEmpty != nil }

    public var primaryBalance: BalanceInfo? { balance?.primary }

    public func currentCredential(_ account: CredentialAccount) -> String? {
        credentials.read(account)
    }

    // MARK: - 刷新

    /// 启动时加载缓存先渲染，再由调度器发起刷新
    public func loadCache() {
        guard let cached = cache.load() else { return }
        balance = cached.balance
        lastUpdated = cached.lastUpdated
    }

    /// 刷新余额；force=false 时受 5 秒节流约束
    /// 返回值表示余额链路是否成功（未配置凭据时返回 false）
    @discardableResult
    public func refreshNow(force: Bool = false) async -> Bool {
        guard throttle.shouldAllow(now: now(), force: force) else {
            return balance != nil
        }
        throttle.record(now: now())
        balanceError = nil

        guard let apiKey = credentials.read(.apiKey)?.trimmed, !apiKey.isEmpty else {
            balanceError = .notConfigured
            return false
        }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            balance = try await balanceClient.fetchBalance(apiKey: apiKey)
            balanceError = nil
            lastUpdated = now()
            persistCache()
            return true
        } catch {
            // 失败时保留缓存中的 balance 供离线展示
            balanceError = AppError.wrap(error)
            return false
        }
    }

    /// 面板打开时调用：数据过期才刷新
    public func refreshIfStale(maxAge: TimeInterval) async {
        guard isConfigured else { return }
        if let last = lastUpdated, now().timeIntervalSince(last) < maxAge { return }
        await refreshNow()
    }

    // MARK: - 凭据配置（设置窗口）

    /// 保存并立即验证 API Key；成功返回 nil 并刷新余额
    @discardableResult
    public func saveAPIKey(_ rawKey: String) async -> AppError? {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return .invalidAPIKey }
        do {
            let snapshot = try await balanceClient.fetchBalance(apiKey: key)
            do {
                try credentials.save(key, for: .apiKey)
            } catch {
                return AppError.wrap(error)
            }
            balance = snapshot
            balanceError = nil
            lastUpdated = now()
            persistCache()
            return nil
        } catch {
            let appError = AppError.wrap(error)
            balanceError = appError
            return appError
        }
    }

    public func removeAPIKey() {
        credentials.delete(.apiKey)
        persistCache()
    }

    private func persistCache() {
        cache.save(CachedState(balance: balance, lastUpdated: lastUpdated))
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
