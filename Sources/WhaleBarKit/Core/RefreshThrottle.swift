import Foundation

/// 手动刷新节流（纯逻辑，便于测试）
public struct RefreshThrottle: Sendable, Equatable {
    public let minimumInterval: TimeInterval
    public private(set) var lastAttempt: Date?

    public init(minimumInterval: TimeInterval = 5) {
        self.minimumInterval = minimumInterval
    }

    /// force 为 true 时不限流（定时器路径）
    public mutating func shouldAllow(now: Date, force: Bool) -> Bool {
        if force { return true }
        if let last = lastAttempt, now.timeIntervalSince(last) < minimumInterval { return false }
        return true
    }

    public mutating func record(now: Date) {
        lastAttempt = now
    }
}
