import Foundation

enum SignInMethod: String, Codable {
    case email, apple
}

struct SkaterProfile: Codable {
    var name: String
    var stance: SkateStance = .regular
    var bio: String = ""
    var avatar: SkateAttachment?
}

struct CrewFollow: Hashable, Codable {
    let follower: UUID
    let skater: UUID
}

struct ConversationDraft: Identifiable, Codable {
    var id = UUID()
    let peer: UUID
    let body: String
    var savedAt = Date()
}

struct CrewMessage: Identifiable, Codable {
    var id = UUID()
    let sender: UUID
    let recipient: UUID
    let body: String
    var date = Date()
}

enum SafetySubject: Hashable, Codable {
    case line(String)
    case skater(UUID)
    case comment(UUID)
    case conversation(UUID)

    private enum Keys: String, CodingKey { case kind, id, line, skater, comment, conversation, _0 }

    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: Keys.self)
        if let kind = try fields.decodeIfPresent(String.self, forKey: .kind) {
            switch kind {
            case "line": self = .line(try fields.decode(String.self, forKey: .id))
            case "skater": self = .skater(try fields.decode(UUID.self, forKey: .id))
            case "comment": self = .comment(try fields.decode(UUID.self, forKey: .id))
            case "conversation": self = .conversation(try fields.decode(UUID.self, forKey: .id))
            default: throw NinaIssue("A recorded report could not be opened.")
            }
        } else if fields.contains(.line) {
            self = .line(try fields.nestedContainer(keyedBy: Keys.self, forKey: .line).decode(String.self, forKey: ._0))
        } else if fields.contains(.skater) {
            self = .skater(try fields.nestedContainer(keyedBy: Keys.self, forKey: .skater).decode(UUID.self, forKey: ._0))
        } else if fields.contains(.comment) {
            self = .comment(try fields.nestedContainer(keyedBy: Keys.self, forKey: .comment).decode(UUID.self, forKey: ._0))
        } else if fields.contains(.conversation) {
            self = .conversation(try fields.nestedContainer(keyedBy: Keys.self, forKey: .conversation).decode(UUID.self, forKey: ._0))
        } else {
            throw NinaIssue("A recorded report could not be opened.")
        }
    }

    func encode(to encoder: Encoder) throws {
        var fields = encoder.container(keyedBy: Keys.self)
        switch self {
        case .line(let id): try fields.encode("line", forKey: .kind); try fields.encode(id, forKey: .id)
        case .skater(let id): try fields.encode("skater", forKey: .kind); try fields.encode(id, forKey: .id)
        case .comment(let id): try fields.encode("comment", forKey: .kind); try fields.encode(id, forKey: .id)
        case .conversation(let id): try fields.encode("conversation", forKey: .kind); try fields.encode(id, forKey: .id)
        }
    }
}

enum SafetyReason: String, CaseIterable, Codable, Identifiable {
    case harassment = "Harassment or threats"
    case hate = "Hate or discrimination"
    case sexual = "Sexual content or child safety"
    case privacy = "Privacy or impersonation"
    case rights = "Credit or copyright"
    case spam = "Spam or dangerous activity"

    var id: Self { self }
}

struct SafetyReport: Identifiable, Codable {
    var id = UUID()
    let subject: SafetySubject
    let reason: SafetyReason
    var date = Date()
}

struct CrewEvent: Identifiable, Codable {
    enum Kind: String, Codable { case follow, submission, report, message }
    var id = UUID()
    let owner: UUID
    let actor: UUID?
    let kind: Kind
    let detail: String
    var messageID: UUID?
    var date = Date()
    var read = false
}

struct SkaterAccount: Identifiable, Codable {
    var id = UUID()
    let loginKey: String
    let method: SignInMethod
    var profile: SkaterProfile
    var agreementDate = Date()
    var blocked: Set<UUID> = []
    var saved: Set<String> = []
    var liked: Set<String> = []
    var spots: [SkateSpot] = []
    var attempts: [TrickAttempt] = []
    var submissions: [LineSubmission] = []
    var drafts: [ConversationDraft] = []
    var reports: [SafetyReport] = []
    var grip: [GripEntry] = []
    var covers: Set<JournalCover> = []
    var selectedCover: JournalCover?

    var balance: Int { max(0, grip.reduce(0) { $0 + $1.amount }) }
    func reported(_ subject: SafetySubject) -> Bool { reports.contains { $0.subject == subject } }
}
