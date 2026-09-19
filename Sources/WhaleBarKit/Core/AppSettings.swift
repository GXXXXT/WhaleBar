import Foundation
import Observation

/// 刷新间隔档位
public enum RefreshInterval: Int, CaseIterable, Identifiable, Sendable {
    case one = 1
    case five = 5
    case fifteen = 15
    case thirty = 30

    public var id: Int { rawValue }
    public var seconds: TimeInterval { TimeInterval(rawValue * 60) }
    public var displayName: String { "\(rawValue) 分钟" }
}

/// 菜单栏显示样式
public enum StatusDisplayStyle: String, CaseIterable, Identifiable, Sendable {
    case iconAndNumber
    case numberOnly
    case iconOnly

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .iconAndNumber: return "图标 + 数字"
        case .numberOnly: return "仅数字"
        case .iconOnly: return "仅图标"
        }
    }
}

/// 用户设置（UserDefaults 持久化）
///
/// 注意：必须用存储属性承载设置值（@Observable 只跟踪存储属性），
/// 计算属性 + UserDefaults 的写法不会触发界面刷新。
@MainActor
@Observable
public final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    /// 设置变化回调（组合根注入，用于重启 RefreshScheduler）
    @ObservationIgnored public var onChange: (() -> Void)?

    public var refreshInterval: RefreshInterval {
        didSet { persist(Keys.refreshInterval, refreshInterval.rawValue); onChange?() }
    }

    public var displayStyle: StatusDisplayStyle {
        didSet { persist(Keys.displayStyle, displayStyle.rawValue); onChange?() }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.refreshInterval = RefreshInterval(rawValue: defaults.integer(forKey: Keys.refreshInterval)) ?? .five
        self.displayStyle = StatusDisplayStyle(rawValue: defaults.string(forKey: Keys.displayStyle) ?? "") ?? .iconAndNumber
    }

    public static let standard = AppSettings()

    private func persist(_ key: String, _ value: Any) {
        defaults.set(value, forKey: key)
    }

    private enum Keys {
        static let refreshInterval = "refreshIntervalMinutes"
        static let displayStyle = "statusDisplayStyle"
    }
}
