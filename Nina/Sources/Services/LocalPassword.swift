import Foundation
import Security

// Account deletion also clears password verifiers left by earlier app versions.
enum LocalPassword {
    static func remove(_ owner: UUID) throws {
        let status = SecItemDelete(query(owner) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NinaIssue("The saved password could not be cleared.")
        }
    }

    private static func query(_ owner: UUID) -> [String: Any] {
        let service = Bundle.main.bundleIdentifier ?? "com.funchan666.nina"
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service + ".local-password",
            kSecAttrAccount as String: owner.uuidString
        ]
    }
}
