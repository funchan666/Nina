import CryptoKit
import Foundation

enum NinaArchiveImport {
    static func decode(_ data: Data) throws -> NinaArchive {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NinaIssue("The saved journal could not be opened.")
        }
        guard let version = object["version"] as? Int, version == 2 || version == 3 else {
            return try JSONDecoder().decode(NinaArchive.self, from: data)
        }
        guard var accounts = object["accounts"] as? [String: Any] else {
            throw NinaIssue("The saved skate profiles could not be opened.")
        }
        // RN used opaque record strings. Preserve account UUIDs and map record references consistently.
        for key in Array(accounts.keys) {
            guard var account = accounts[key] as? [String: Any] else {
                throw NinaIssue("A saved skate profile could not be opened.")
            }
            for (field, references) in [
                ("spots", ["id"]), ("attempts", ["id", "spotID"]), ("submissions", ["id"]), ("drafts", ["id"])
            ] {
                account[field] = try records(account[field], identifiers: references)
            }
            account["reports"] = try records(account["reports"], identifiers: ["id"]).map { report in
                var report = report
                guard var subject = report["subject"] as? [String: Any] else {
                    throw NinaIssue("A recorded report could not be opened.")
                }
                if subject["kind"] as? String == "comment" {
                    guard let id = subject["id"] as? String else { throw NinaIssue("A recorded comment could not be opened.") }
                    subject["id"] = identifier(id)
                }
                report["subject"] = subject
                return report
            }
            accounts[key] = account
        }
        object["accounts"] = accounts
        object["comments"] = try records(object["comments"], identifiers: ["id"])
        object["activity"] = try records(object["activity"], identifiers: ["id"], optionalIdentifiers: ["messageID"])
        if version >= 3 { object["messages"] = try records(object["messages"], identifiers: ["id"]) }
        return try JSONDecoder().decode(NinaArchive.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private static func records(_ value: Any?, identifiers: [String], optionalIdentifiers: [String] = []) throws -> [[String: Any]] {
        guard let array = value as? [[String: Any]] else { throw NinaIssue("A saved journal record could not be opened.") }
        return try array.map { original in
            var record = original
            for field in identifiers {
                guard let value = record[field] as? String, !value.isEmpty else {
                    throw NinaIssue("A saved journal identifier could not be opened.")
                }
                record[field] = identifier(value)
            }
            for field in optionalIdentifiers where record[field] != nil && !(record[field] is NSNull) {
                guard let value = record[field] as? String, !value.isEmpty else {
                    throw NinaIssue("A saved journal reference could not be opened.")
                }
                record[field] = identifier(value)
            }
            return record
        }
    }

    private static func identifier(_ value: String) -> String {
        if let existing = UUID(uuidString: value) { return existing.uuidString }
        let hash = SHA256.hash(data: Data(("nina.record:" + value).utf8))
        var hex = Array(hash.map { String(format: "%02x", $0) }.joined().prefix(32))
        hex[12] = "8"
        hex[16] = "a"
        let sections = [0..<8, 8..<12, 12..<16, 16..<20, 20..<32]
        return sections.map { String(hex[$0]) }.joined(separator: "-")
    }
}
