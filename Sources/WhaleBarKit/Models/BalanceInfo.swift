import Foundation

/// 单币种余额明细（金额单位为币种本位，保留两位小数展示）
public struct BalanceInfo: Codable, Equatable, Hashable, Sendable {
    public let currency: String
    public let total: Decimal
    public let granted: Decimal
    public let toppedUp: Decimal

    public init(currency: String, total: Decimal, granted: Decimal, toppedUp: Decimal) {
        self.currency = currency
        self.total = total
        self.granted = granted
        self.toppedUp = toppedUp
    }
}

/// 一次余额查询的完整快照
public struct BalanceSnapshot: Codable, Equatable, Sendable {
    public let isAvailable: Bool
    public let infos: [BalanceInfo]

    public init(isAvailable: Bool, infos: [BalanceInfo]) {
        self.isAvailable = isAvailable
        self.infos = infos
    }

    /// v1 展示主币种：优先 CNY，否则取总余额最大者
    public var primary: BalanceInfo? {
        if let cny = infos.first(where: { $0.currency == "CNY" }) { return cny }
        return infos.max { $0.total < $1.total }
    }
}
