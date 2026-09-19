import Foundation
import WhaleBarKit

func runBalanceChecks() async {
    await suite("DeepSeekBalanceClient") {
        await checkNoThrow("解析官方余额响应，主币种优先 CNY，请求头正确") {
            StubURLProtocol.handler = { _ in
                (200, Data(#"{"is_available": true, "balance_infos": [{"currency": "CNY", "total_balance": "110.00", "granted_balance": "10.00", "topped_up_balance": "100.00"}]}"#.utf8))
            }
            defer { StubURLProtocol.reset() }

            let client = DeepSeekBalanceClient(httpClient: URLSessionHTTPClient(session: TestURLSession.stubbed()))
            let snapshot = try await client.fetchBalance(apiKey: "sk-test")

            check(snapshot.isAvailable, "is_available 为 true")
            checkEqual(snapshot.infos.count, 1, "币种数量为 1")
            checkOptionalEqual(snapshot.primary?.currency, "CNY", "主币种为 CNY")
            checkOptionalEqual(snapshot.primary?.total, Decimal(string: "110.00"), "总余额解析")
            checkOptionalEqual(snapshot.primary?.granted, Decimal(string: "10.00"), "赠送余额解析")
            checkOptionalEqual(snapshot.primary?.toppedUp, Decimal(string: "100.00"), "充值余额解析")
            checkOptionalEqual(StubURLProtocol.lastRequest?.url?.path, "/user/balance", "请求路径")
            checkOptionalEqual(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test", "鉴权头")
        }

        await checkNoThrow("无 CNY 时取总余额最大币种") {
            StubURLProtocol.handler = { _ in
                (200, Data(#"{"is_available": true, "balance_infos": [{"currency": "USD", "total_balance": "5.00", "granted_balance": "0.00", "topped_up_balance": "5.00"}, {"currency": "EUR", "total_balance": "9.00", "granted_balance": "0.00", "topped_up_balance": "9.00"}]}"#.utf8))
            }
            defer { StubURLProtocol.reset() }

            let client = DeepSeekBalanceClient(httpClient: URLSessionHTTPClient(session: TestURLSession.stubbed()))
            let snapshot = try await client.fetchBalance(apiKey: "sk-test")
            checkOptionalEqual(snapshot.primary?.currency, "EUR", "主币种取余额最大者")
        }

        await checkNoThrow("金额字段缺失时回落为 0") {
            StubURLProtocol.handler = { _ in
                (200, Data(#"{"is_available": true, "balance_infos": [{"currency": "CNY", "total_balance": "12.34"}]}"#.utf8))
            }
            defer { StubURLProtocol.reset() }

            let client = DeepSeekBalanceClient(httpClient: URLSessionHTTPClient(session: TestURLSession.stubbed()))
            let snapshot = try await client.fetchBalance(apiKey: "sk-test")
            checkOptionalEqual(snapshot.primary?.total, Decimal(string: "12.34"), "总余额解析")
            checkOptionalEqual(snapshot.primary?.granted, Decimal(0), "缺失字段回落 0")
        }

        await checkThrowsAppError("401 映射为 invalidAPIKey", expected: .invalidAPIKey) {
            StubURLProtocol.handler = { _ in (401, Data("{}".utf8)) }
            defer { StubURLProtocol.reset() }
            let client = DeepSeekBalanceClient(httpClient: URLSessionHTTPClient(session: TestURLSession.stubbed()))
            _ = try await client.fetchBalance(apiKey: "bad")
        }

        await checkThrowsAppError("429 映射为 rateLimited", expected: .rateLimited) {
            StubURLProtocol.handler = { _ in (429, Data("{}".utf8)) }
            defer { StubURLProtocol.reset() }
            let client = DeepSeekBalanceClient(httpClient: URLSessionHTTPClient(session: TestURLSession.stubbed()))
            _ = try await client.fetchBalance(apiKey: "sk")
        }

        await checkThrowsAppError("非法 JSON 映射为 decoding", expected: .decoding("余额响应解析失败")) {
            StubURLProtocol.handler = { _ in (200, Data("not json".utf8)) }
            defer { StubURLProtocol.reset() }
            let client = DeepSeekBalanceClient(httpClient: URLSessionHTTPClient(session: TestURLSession.stubbed()))
            _ = try await client.fetchBalance(apiKey: "sk")
        }
    }
}
