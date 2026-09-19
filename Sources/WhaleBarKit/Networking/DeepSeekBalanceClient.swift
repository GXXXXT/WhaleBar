import Foundation

/// DeepSeek 官方 API 客户端（余额）
/// 文档: https://api-docs.deepseek.com/api/get-user-balance/
public struct DeepSeekBalanceClient: Sendable {
    private let httpClient: any HTTPClientProtocol
    private let baseURL: URL

    public init(
        httpClient: any HTTPClientProtocol = URLSessionHTTPClient(),
        baseURL: URL = URL(string: "https://api.deepseek.com")!
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    public static func live() -> DeepSeekBalanceClient { DeepSeekBalanceClient() }

    public func fetchBalance(apiKey: String) async throws -> BalanceSnapshot {
        var request = URLRequest(url: baseURL.appending(path: "user/balance"))
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await httpClient.data(for: request)
        try Self.checkTransport(response)
        do {
            return try JSONDecoder().decode(BalanceResponse.self, from: data).toModel()
        } catch {
            throw AppError.decoding("余额响应解析失败")
        }
    }

    static func checkTransport(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299: return
        case 401: throw AppError.invalidAPIKey
        case 429: throw AppError.rateLimited
        default: throw AppError.server(response.statusCode)
        }
    }
}

// MARK: - 响应 DTO（字段为官方文档定义的 snake_case；金额为字符串）

private struct BalanceResponse: Decodable {
    let isAvailable: Bool
    let balanceInfos: [DTO]

    enum CodingKeys: String, CodingKey {
        case isAvailable = "is_available"
        case balanceInfos = "balance_infos"
    }

    struct DTO: Decodable {
        let currency: String
        let totalBalance: String
        let grantedBalance: String
        let toppedUpBalance: String

        enum CodingKeys: String, CodingKey {
            case currency
            case totalBalance = "total_balance"
            case grantedBalance = "granted_balance"
            case toppedUpBalance = "topped_up_balance"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            currency = try container.decode(String.self, forKey: .currency)
            totalBalance = try container.decodeIfPresent(String.self, forKey: .totalBalance) ?? "0"
            grantedBalance = try container.decodeIfPresent(String.self, forKey: .grantedBalance) ?? "0"
            toppedUpBalance = try container.decodeIfPresent(String.self, forKey: .toppedUpBalance) ?? "0"
        }
    }

    func toModel() -> BalanceSnapshot {
        let infos = balanceInfos.map { dto in
            BalanceInfo(
                currency: dto.currency,
                total: Decimal(string: dto.totalBalance) ?? 0,
                granted: Decimal(string: dto.grantedBalance) ?? 0,
                toppedUp: Decimal(string: dto.toppedUpBalance) ?? 0
            )
        }
        return BalanceSnapshot(isAvailable: isAvailable, infos: infos)
    }
}
