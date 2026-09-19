import Foundation

/// 全局错误模型：UI 层根据 userMessage 呈现
public enum AppError: Error, Equatable, Sendable {
    case notConfigured
    case invalidAPIKey
    case rateLimited
    case network(String)
    case decoding(String)
    case server(Int)
    case unknown(String)

    public var userMessage: String {
        switch self {
        case .notConfigured: return "尚未配置凭据"
        case .invalidAPIKey: return "API Key 无效，请重新配置"
        case .rateLimited: return "请求过于频繁，已自动降频重试"
        case .network(let detail): return "网络不可用：\(detail)"
        case .decoding(let detail): return "接口响应异常（\(detail)），可能已改版"
        case .server(let code): return "服务端错误（HTTP \(code)）"
        case .unknown(let detail): return "未知错误：\(detail)"
        }
    }

    /// 将底层错误归一为 AppError（客户端已映射过的 AppError 原样返回）
    public static func wrap(_ error: Error) -> AppError {
        if let appError = error as? AppError { return appError }
        if error is DecodingError { return .decoding("解析失败") }
        if let urlError = error as? URLError { return .network(urlError.localizedDescription) }
        return .unknown(error.localizedDescription)
    }
}
