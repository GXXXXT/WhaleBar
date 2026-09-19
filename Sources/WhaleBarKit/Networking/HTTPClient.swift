import Foundation

/// 可注入的 HTTP 传输抽象（测试用 URLProtocol stub 替换）
public protocol HTTPClientProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPClient: HTTPClientProtocol {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.network("非 HTTP 响应")
        }
        return (data, http)
    }
}
