import Foundation
import Security

enum SessionVault {
    private static var lookup: [String: AnyObject] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "com.funchan666.nina") as NSString,
            kSecAttrAccount as String: "active-skater" as NSString
        ]
    }

    static func read() throws -> UUID? {
        let query = lookup.merging([
            kSecReturnData as String: NSNumber(value: true),
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let text = String(data: data, encoding: .utf8), let id = UUID(uuidString: text) else {
            throw NinaIssue("Your sign-in couldn't be read. Unlock your iPhone and try again.")
        }
        return id
    }

    static func write(_ id: UUID?) throws {
        let status: OSStatus
        if let id {
            let data = Data(id.uuidString.utf8)
            let update = SecItemUpdate(lookup as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            if update == errSecItemNotFound {
                var entry = lookup
                entry[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                entry[kSecValueData as String] = data as NSData
                status = SecItemAdd(entry as CFDictionary, nil)
            } else {
                status = update
            }
        } else {
            status = SecItemDelete(lookup as CFDictionary)
            if status == errSecItemNotFound { return }
        }
        guard status == errSecSuccess else { throw NinaIssue("Your sign-in couldn't be saved. Try again.") }
    }
}
