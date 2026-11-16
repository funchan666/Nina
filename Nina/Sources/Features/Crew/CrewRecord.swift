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

enum SafetySubject: Hashable, Codable {
    case line(String)
    case skater(UUID)
    case comment(UUID)
    case conversation(UUID)
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
    enum Kind: String, Codable { case follow, submission, report }
    var id = UUID()
    let owner: UUID
    let actor: UUID?
    let kind: Kind
    let detail: String
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
