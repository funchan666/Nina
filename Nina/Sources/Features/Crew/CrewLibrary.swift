import Foundation

extension NinaLibrary {
    func isBlocked(_ peer: UUID) -> Bool {
        guard let me, let other = archive.accounts[peer] else { return false }
        return me.blocked.contains(peer) || other.blocked.contains(me.id)
    }

    func visibleSkater(_ id: UUID) -> SkaterAccount? {
        guard let me, !isBlocked(id), !me.reported(.skater(id)) else { return nil }
        return archive.accounts[id]
    }

    var crew: [SkaterAccount] {
        archive.accounts.keys.compactMap { id in
            id == activeID ? nil : visibleSkater(id)
        }.sorted { left, right in
            let order = left.profile.name.localizedCaseInsensitiveCompare(right.profile.name)
            return order == .orderedSame ? left.id.uuidString < right.id.uuidString : order == .orderedAscending
        }
    }

    func follows(_ peer: UUID) -> Bool {
        guard let activeID else { return false }
        return archive.follows.contains(CrewFollow(follower: activeID, skater: peer))
    }

    func canContact(_ peer: UUID) -> Bool {
        guard let activeID, activeID != peer, visibleSkater(peer) != nil,
              !((me?.reported(.conversation(peer))) ?? false) else { return false }
        return follows(peer) && archive.follows.contains(CrewFollow(follower: peer, skater: activeID))
    }

    func relations(for owner: UUID, incoming: Bool) -> [SkaterAccount] {
        let ids = archive.follows.compactMap { edge -> UUID? in
            if incoming, edge.skater == owner { return edge.follower }
            if !incoming, edge.follower == owner { return edge.skater }
            return nil
        }
        return ids.compactMap(visibleSkater).sorted { $0.profile.name < $1.profile.name }
    }

    func toggleFollow(_ peer: UUID) throws {
        let id = try accountID()
        guard peer != id, let skater = visibleSkater(peer) else { throw NinaIssue("This profile is unavailable.") }
        let edge = CrewFollow(follower: id, skater: skater.id)
        try commit { next in
            if next.follows.remove(edge) == nil {
                next.follows.insert(edge)
                next.activity.removeAll { $0.owner == peer && $0.actor == id && $0.kind == .follow }
                next.activity.insert(CrewEvent(owner: peer, actor: id, kind: .follow, detail: ""), at: 0)
            } else {
                next.activity.removeAll { $0.owner == peer && $0.actor == id && $0.kind == .follow }
            }
        }
    }

    func setBlocked(_ peer: UUID, blocked: Bool) throws {
        let id = try accountID()
        guard id != peer, archive.accounts[peer] != nil else { throw NinaIssue("This profile is unavailable.") }
        try commit { next in
            if blocked {
                next.accounts[id]?.blocked.insert(peer)
                next.follows = next.follows.filter { edge in
                    !(edge.follower == id && edge.skater == peer) && !(edge.follower == peer && edge.skater == id)
                }
                next.activity.removeAll { ($0.owner == id && $0.actor == peer) || ($0.owner == peer && $0.actor == id) }
            } else {
                next.accounts[id]?.blocked.remove(peer)
            }
        }
    }

    func saveDraft(to peer: UUID, body: String) throws {
        guard canContact(peer) else { throw NinaIssue("Drafts are available once both skaters follow each other.") }
        let text = try body.validatedText(label: "a message", limit: 600)
        try updateAccount { account in
            if let index = account.drafts.firstIndex(where: { $0.peer == peer }) {
                account.drafts[index] = ConversationDraft(id: account.drafts[index].id, peer: peer, body: text)
            } else {
                account.drafts.insert(ConversationDraft(peer: peer, body: text), at: 0)
            }
        }
    }

    func discardDraft(to peer: UUID) throws {
        try updateAccount { $0.drafts.removeAll { $0.peer == peer } }
    }

    func messages(with peer: UUID) -> [CrewMessage] {
        guard let activeID else { return [] }
        return archive.messages.filter {
            ($0.sender == activeID && $0.recipient == peer) || ($0.sender == peer && $0.recipient == activeID)
        }.sorted { $0.date < $1.date }
    }

    func sendMessage(to peer: UUID, body: String) throws {
        guard canContact(peer) else { throw NinaIssue("Both skaters must follow each other before sending messages.") }
        let owner = try accountID()
        let text = try body.validatedText(label: "a message", limit: 600)
        let message = CrewMessage(sender: owner, recipient: peer, body: text)
        try commit { next in
            next.messages.append(message)
            next.accounts[owner]?.drafts.removeAll { $0.peer == peer }
            next.activity.insert(CrewEvent(owner: peer, actor: owner, kind: .message, detail: text, messageID: message.id), at: 0)
        }
    }

    func removeMessage(_ id: UUID) throws {
        let owner = try accountID()
        guard archive.messages.contains(where: { $0.id == id && $0.sender == owner }) else {
            throw NinaIssue("This message is unavailable.")
        }
        try commit { next in
            next.messages.removeAll { $0.id == id }
            next.activity.removeAll { $0.messageID == id }
        }
    }

    func markConversationRead(_ peer: UUID) throws {
        let owner = try accountID()
        guard activity.contains(where: { $0.kind == .message && $0.actor == peer && !$0.read }) else { return }
        try commit { next in
            for index in next.activity.indices where next.activity[index].owner == owner &&
                next.activity[index].actor == peer && next.activity[index].kind == .message {
                next.activity[index].read = true
            }
        }
    }

    func updateProfile(_ draft: SkaterProfile) throws {
        var profile = draft
        profile.name = try profile.name.validatedText(label: "a display name", limit: 32)
        profile.bio = try profile.bio.validatedText(label: "a bio", limit: 200, required: false)
        try updateAccount { $0.profile = profile }
    }

    var activity: [CrewEvent] {
        archive.activity.filter { event in
            event.owner == activeID && event.actor.map {
                visibleSkater($0) != nil && (event.kind != .message || me?.reported(.conversation($0)) != true)
            } != false
        }
    }

    var unread: Int { activity.filter { !$0.read }.count }

    func markActivityRead() throws {
        let ids = Set(activity.filter { !$0.read }.map(\.id))
        guard !ids.isEmpty else { return }
        try commit { next in
            for index in next.activity.indices where ids.contains(next.activity[index].id) {
                next.activity[index].read = true
            }
        }
    }

    func fileReport(_ subject: SafetySubject, reason: SafetyReason) throws {
        let id = try accountID()
        guard me?.reported(subject) != true else { return }
        try commit { next in
            next.accounts[id]?.reports.append(SafetyReport(subject: subject, reason: reason))
            next.activity.insert(CrewEvent(owner: id, actor: nil, kind: .report, detail: "Report recorded. Item hidden."), at: 0)
        }
    }
}
