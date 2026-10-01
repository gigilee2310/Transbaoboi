import Foundation
import Security

enum Keychain {
    private static let service = "com.gigilee.baoboiii"
    private static let geminiAccount = "gemini-api-key"

    static var geminiAPIKey: String? {
        get { read(account: geminiAccount) }
        set {
            if let newValue, !newValue.isEmpty {
                save(newValue, account: geminiAccount)
            } else {
                delete(account: geminiAccount)
            }
        }
    }

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func read(account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func save(_ value: String, account: String) {
        delete(account: account)
        var query = baseQuery(account)
        query[kSecValueData as String] = Data(value.utf8)
        // Readable in the background (Shortcuts) once the phone has been unlocked after boot.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func delete(account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }
}
