import Foundation
import Security

/// 凭据账户类别
public enum CredentialAccount: String, Sendable {
    case apiKey
    case userToken
}

/// 凭据存储抽象（生产实现为 Keychain，测试可注入内存实现）
public protocol CredentialStoring: Sendable {
    func read(_ account: CredentialAccount) -> String?
    func save(_ value: String, for account: CredentialAccount) throws
    func delete(_ account: CredentialAccount)
}

/// Keychain GenericPassword 存储：API Key / userToken 不落明文
public struct KeychainStore: CredentialStoring {
    private let service: String

    public init(service: String = "com.heyhansir.WhaleBar") {
        self.service = service
    }

    public static let standard = KeychainStore()

    public func read(_ account: CredentialAccount) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func save(_ value: String, for account: CredentialAccount) throws {
        let data = Data(value.utf8)
        let query = baseQuery(account)
        let update: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            guard SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess else {
                throw AppError.unknown("Keychain 写入失败")
            }
        } else if status != errSecSuccess {
            throw AppError.unknown("Keychain 更新失败（\(status)）")
        }
    }

    public func delete(_ account: CredentialAccount) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }

    private func baseQuery(_ account: CredentialAccount) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue,
        ]
    }
}
