import Foundation

public extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// 展示格式化工具
public enum Format {
    /// 金额：符号 + 两位小数（千分位）
    public static func money(_ value: Decimal, currency: String) -> String {
        symbol(for: currency) + grouped(value)
    }

    static func symbol(for code: String) -> String {
        switch code.trimmed {
        case "CNY": return "¥"
        case "USD": return "$"
        case "EUR": return "€"
        case let other: return other + " "
        }
    }

    public static func grouped(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    /// HH:mm 本地时间
    public static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    /// yyyy-MM-dd → MM-dd（图表轴标签）
    public static func shortDay(_ day: String) -> String {
        guard day.count >= 10 else { return day }
        return String(day.suffix(5))
    }
}

public enum CurrencySymbol {
    public static func symbol(for code: String?) -> String {
        guard let code else { return "¥" }
        return Format.symbol(for: code)
    }
}
