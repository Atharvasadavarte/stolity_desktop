import Foundation
import Security
import os.log

private let keychainLogger = Logger(
    subsystem: "com.stolity.StolityFileProvider",
    category: "keychain"
)

enum KeychainHelper {
    private static let service     = "com.stolity.token"
    private static let account     = "bearer"
    private static let accessGroup = "ZLL9J8KZ7J.com.stolity.shared"

    static func readToken() -> String? {
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     account,
            kSecAttrAccessGroup: accessGroup,
            kSecReturnData:      true,
            kSecMatchLimit:      kSecMatchLimitOne,
        ]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        keychainLogger.info("Keychain read status: \(status, privacy: .public) (0 = success, -25300 = not found)")

        guard status == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty
        else {
            keychainLogger.info("Token found in keychain: false")
            return nil
        }
        keychainLogger.info("Token found in keychain: true, length: \(token.count, privacy: .public)")
        return token
    }
}
