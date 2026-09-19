import Foundation

/// 本地缓存（Application Support/WhaleBar/cache.json），用于离线展示与启动提速
public struct CachedState: Codable, Equatable, Sendable {
    public var balance: BalanceSnapshot?
    public var lastUpdated: Date?

    public init(balance: BalanceSnapshot? = nil, lastUpdated: Date? = nil) {
        self.balance = balance
        self.lastUpdated = lastUpdated
    }
}

public struct CacheStore: Sendable {
    public let fileURL: URL

    public init(directory: URL? = nil) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("WhaleBar", isDirectory: true)
        let dir = directory ?? appSupport ?? FileManager.default.temporaryDirectory.appendingPathComponent("WhaleBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("cache.json")
    }

    public static let standard = CacheStore()

    public func load() -> CachedState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CachedState.self, from: data)
    }

    public func save(_ state: CachedState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
