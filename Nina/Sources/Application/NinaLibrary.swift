import Combine
import CryptoKit
import Foundation

struct NinaArchive: Codable {
    let version: Int = 1
    var accounts: [UUID: SkaterAccount] = [:]
    var follows: Set<CrewFollow> = []
    var comments: [LineComment] = []
    var activity: [CrewEvent] = []
    var receipts: [String: GripReceipt] = [:]
    var retiredAccounts: Set<UUID> = []

    private enum CodingKeys: String, CodingKey {
        case version, accounts, follows, comments, activity, receipts, retiredAccounts
    }

    init() {}

    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let storedVersion = try fields.decodeIfPresent(Int.self, forKey: .version) ?? 1
        guard storedVersion == version else { throw NinaIssue("This version can't open your journal.") }
        accounts = try fields.decodeIfPresent([UUID: SkaterAccount].self, forKey: .accounts) ?? [:]
        follows = try fields.decodeIfPresent(Set<CrewFollow>.self, forKey: .follows) ?? []
        comments = try fields.decodeIfPresent([LineComment].self, forKey: .comments) ?? []
        activity = try fields.decodeIfPresent([CrewEvent].self, forKey: .activity) ?? []
        receipts = try fields.decodeIfPresent([String: GripReceipt].self, forKey: .receipts) ?? [:]
        retiredAccounts = try fields.decodeIfPresent(Set<UUID>.self, forKey: .retiredAccounts) ?? []
    }
}

struct NinaIssue: LocalizedError {
    let text: String
    init(_ text: String) { self.text = text }
    var errorDescription: String? { text }
}

@MainActor
final class NinaLibrary: ObservableObject {
    @Published private(set) var archive = NinaArchive()
    @Published private(set) var activeID: UUID?
    @Published private(set) var deletionNotice: String?
    private var location: URL?

    var me: SkaterAccount? { activeID.flatMap { archive.accounts[$0] } }

    func load() throws {
        guard location == nil else { return }
        let folder = try NinaFiles.root()
        let file = folder.appendingPathComponent("journal-v1.json")
        let incoming: NinaArchive
        if FileManager.default.fileExists(atPath: file.path) {
            incoming = try JSONDecoder().decode(NinaArchive.self, from: Data(contentsOf: file))
        } else {
            incoming = NinaArchive()
        }
        let session = try SessionVault.read()
        archive = incoming
        activeID = session.flatMap { incoming.accounts[$0]?.id }
        location = file
        if session != nil, activeID == nil { try? SessionVault.write(nil) }
        for retired in incoming.retiredAccounts {
            try? NinaFiles.removeAccount(retired)
        }
    }

    func signIn(email: String, password: String) throws {
        let address = email.cleaned.lowercased()
        let range = address.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression)
        guard address.count <= 254, range != nil else { throw NinaIssue("Enter a valid email address.") }
        guard !password.isEmpty else { throw NinaIssue("Enter a password to continue.") }
        try openIdentity(key: digest("email:" + address), method: .email, name: nil)
    }

    func signIn(appleSubject: String, fullName: String?) throws {
        guard !appleSubject.isEmpty else { throw NinaIssue("Apple couldn't return your account. Try again.") }
        try openIdentity(key: digest("apple:" + appleSubject), method: .apple, name: fullName)
    }

    private func digest(_ key: String) -> String {
        SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func openIdentity(key: String, method: SignInMethod, name: String?) throws {
        guard activeID == nil else { return }
        if let existing = archive.accounts.values.first(where: { $0.loginKey == key }) {
            try SessionVault.write(existing.id)
            activeID = existing.id
            return
        }
        let publicName = String((name?.cleaned ?? "").prefix(32))
        var account = SkaterAccount(
            loginKey: key, method: method,
            profile: SkaterProfile(name: publicName.isEmpty ? "Skater" : publicName)
        )
        account.grip.append(GripEntry(id: "welcome", label: "Welcome Grip", amount: 20))
        try commit { $0.accounts[account.id] = account }
        try SessionVault.write(account.id)
        activeID = account.id
    }

    func signOut() throws {
        try SessionVault.write(nil)
        activeID = nil
    }

    func deleteAccount() throws {
        let id = try accountID()
        try commit { next in
            let commentIDs = Set(next.comments.filter { $0.authorID == id }.map(\.id))
            next.accounts.removeValue(forKey: id)
            next.retiredAccounts.insert(id)
            next.follows = next.follows.filter { $0.follower != id && $0.skater != id }
            next.comments.removeAll { $0.authorID == id }
            next.activity.removeAll { $0.owner == id || $0.actor == id }
            for otherID in Array(next.accounts.keys) {
                next.accounts[otherID]?.blocked.remove(id)
                next.accounts[otherID]?.drafts.removeAll { $0.peer == id }
                next.accounts[otherID]?.reports.removeAll {
                    switch $0.subject {
                    case .skater(let target), .conversation(let target): return target == id
                    case .comment(let target): return commentIDs.contains(target)
                    case .line: return false
                    }
                }
            }
        }
        deletionNotice = nil
        do {
            try SessionVault.write(nil)
            try NinaFiles.removeAccount(id)
        } catch {
            deletionNotice = "Your profile was removed. Nina will retry clearing remaining data the next time it opens."
        }
        activeID = nil
    }

    func accountID() throws -> UUID {
        guard let activeID, archive.accounts[activeID] != nil else {
            throw NinaIssue("Sign in to keep your changes.")
        }
        return activeID
    }

    func commit(_ change: (inout NinaArchive) throws -> Void) throws {
        guard let location else { throw NinaIssue("Your journal hasn't opened yet.") }
        var next = archive
        try change(&next)
        do {
            let data = try JSONEncoder().encode(next)
            try data.write(to: location, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            throw NinaIssue("Changes couldn't be saved. Check available storage and try again.")
        }
        archive = next
    }

    func updateAccount(_ change: (inout SkaterAccount) throws -> Void) throws {
        let id = try accountID()
        guard var account = archive.accounts[id] else { throw NinaIssue("Your profile is unavailable.") }
        try change(&account)
        try commit { $0.accounts[id] = account }
    }
}

extension String {
    var cleaned: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    func validatedText(label: String, limit: Int, required: Bool = true) throws -> String {
        let value = cleaned
        if required && value.isEmpty { throw NinaIssue("Enter \(label).") }
        guard value.count <= limit else { throw NinaIssue("Keep \(label) within \(limit) characters.") }
        return value
    }
}
