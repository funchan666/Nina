import CommonCrypto
import Foundation
import Security

actor LocalPassword {
    static let shared = LocalPassword()

    private let saltSize = 16
    private let proofSize = 32

    func register(_ password: String, owner: UUID) throws {
        guard password.count >= 8 else { throw NinaIssue("Use at least 8 characters for your password.") }
        let lookup = query(owner)
        if try read(lookup) != nil {
            throw NinaIssue("This email already has a profile on this iPhone. Sign in to open it.")
        }
        var salt = [UInt8](repeating: 0, count: saltSize)
        let status = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }
        guard status == errSecSuccess else { throw NinaIssue("The password could not be set. Try again.") }
        var item = lookup
        item[kSecValueData as String] = Data(salt) + (try proof(password, salt: Data(salt)))
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
            throw NinaIssue("The password could not be set. Unlock your iPhone and try again.")
        }
    }

    func verify(_ password: String, owner: UUID) throws {
        guard let record = try read(query(owner)), record.count == saltSize + proofSize else {
            throw NinaIssue("Create a password on this iPhone to open this email profile.")
        }
        let candidate = try proof(password, salt: Data(record.prefix(saltSize)))
        let difference = zip(record.suffix(proofSize), candidate).reduce(UInt8(0)) { difference, pair in
            difference | (pair.0 ^ pair.1)
        }
        guard difference == 0 else { throw NinaIssue("The email or password is incorrect.") }
    }

    func remove(_ owner: UUID) throws {
        let status = SecItemDelete(query(owner) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NinaIssue("The saved password could not be cleared.")
        }
    }

    private func query(_ owner: UUID) -> [String: Any] {
        let service = Bundle.main.bundleIdentifier ?? "com.funchan666.nina"
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service + ".local-password",
            kSecAttrAccount as String: owner.uuidString
        ]
    }

    private func read(_ lookup: [String: Any]) throws -> Data? {
        var query = lookup
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let value = result as? Data else {
            throw NinaIssue("The saved password could not be read. Unlock your iPhone and try again.")
        }
        return value
    }

    private func proof(_ password: String, salt: Data) throws -> Data {
        let input = Data(password.utf8)
        guard !input.isEmpty, input.count <= 256 else {
            throw NinaIssue("Use a password up to 256 UTF-8 bytes.")
        }
        var output = Data(count: proofSize)
        let status = input.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                output.withUnsafeMutableBytes { hashBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2), passwordBytes.bindMemory(to: Int8.self).baseAddress, input.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        600_000, hashBytes.bindMemory(to: UInt8.self).baseAddress, proofSize
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw NinaIssue("The password could not be checked. Try again.") }
        return output
    }
}
