import Foundation
import WhaleBarKit

func runCacheChecks() async {
    await suite("CacheStore") {
        await checkNoThrow("读写往返") {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("WhaleBarChecks-\(UUID().uuidString)", isDirectory: true)
            let store = CacheStore(directory: dir)
            let state = CachedState(
                balance: BalanceSnapshot(
                    isAvailable: true,
                    infos: [BalanceInfo(currency: "CNY", total: Decimal(string: "42.50")!, granted: Decimal(string: "2.50")!, toppedUp: Decimal(string: "40.00")!)]
                ),
                lastUpdated: Date(timeIntervalSince1970: 1_758_000_000)
            )
            store.save(state)
            checkEqual(store.load(), state, "保存后读取一致")
        }

        await checkNoThrow("损坏文件返回 nil") {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("WhaleBarChecks-\(UUID().uuidString)", isDirectory: true)
            let store = CacheStore(directory: dir)
            try Data("not json".utf8).write(to: store.fileURL)
            checkOptionalEqual(store.load(), nil, "损坏缓存安全回落")
        }

        await checkNoThrow("空目录返回 nil") {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("WhaleBarChecks-\(UUID().uuidString)", isDirectory: true)
            let store = CacheStore(directory: dir)
            checkOptionalEqual(store.load(), nil, "无缓存时为 nil")
        }
    }
}

func runThrottleChecks() async {
    await suite("RefreshThrottle") {
        await checkNoThrow("force 始终放行") {
            var throttle = RefreshThrottle(minimumInterval: 5)
            let t0 = Date(timeIntervalSince1970: 0)
            throttle.record(now: t0)
            check(throttle.shouldAllow(now: t0.addingTimeInterval(1), force: true), "force 不受限流影响")
        }

        await checkNoThrow("间隔内拦截、间隔外放行") {
            var throttle = RefreshThrottle(minimumInterval: 5)
            let t0 = Date(timeIntervalSince1970: 0)
            throttle.record(now: t0)
            check(!throttle.shouldAllow(now: t0.addingTimeInterval(4.9), force: false), "4.9s 内拦截")
            check(throttle.shouldAllow(now: t0.addingTimeInterval(5.1), force: false), "5.1s 后放行")
        }

        await checkNoThrow("未记录时不拦截") {
            var throttle = RefreshThrottle(minimumInterval: 5)
            check(throttle.shouldAllow(now: Date(), force: false), "首次请求放行")
        }
    }
}
