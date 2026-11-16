import SwiftUI

private enum MessageSection: String, CaseIterable {
    case drafts = "Drafts"
    case activity = "Activity"
}

struct MessagesPage: View {
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @State private var section = MessageSection.drafts

    var body: some View {
        NinaPage("Messages", ground: "CrewGround") {
            NinaChoices(choices: MessageSection.allCases, selection: $section) {
                $0 == .activity && library.unread > 0 ? "Activity (\(library.unread))" : $0.rawValue
            }
            if section == .drafts { drafts } else { activity }
        }
    }

    private var drafts: some View {
        let drafts = (library.me?.drafts ?? []).filter {
            library.visibleSkater($0.peer) != nil && library.me?.reported(.conversation($0.peer)) != true
        }.sorted { $0.savedAt > $1.savedAt }
        return VStack(alignment: .leading, spacing: 7) {
            if drafts.isEmpty {
                NinaEmpty(icon: .comment, title: "No message drafts", note: "Open a skater’s profile to find their chat.")
            }
            ForEach(drafts) { draft in
                if let peer = library.visibleSkater(draft.peer) {
                    NinaRow(title: peer.profile.name, detail: draft.body, icon: .comment) {
                        flow.open(.conversation(peer.id))
                    }
                }
            }
        }
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 7) {
            if library.unread > 0 {
                NinaButton("Mark activity read", icon: .check, kind: .paper) { flow.run { try library.markActivityRead() } }
            }
            if library.activity.isEmpty {
                NinaEmpty(icon: .comment, title: "No activity", note: "Updates from your profile and submissions will appear here.")
            }
            ForEach(library.activity) { event in
                switch event.kind {
                case .follow:
                    if let actor = event.actor.flatMap(library.visibleSkater) {
                        NinaRow(title: actor.profile.name + " followed you", detail: event.read ? nil : "Unread", icon: .crew) {
                            flow.open(.profile(actor.id))
                        }
                    }
                case .submission:
                    NinaRow(title: "Saved for review", detail: event.detail, icon: .deck) { flow.open(.submissions) }
                case .report:
                    NinaNotice(text: event.detail)
                }
            }
        }
    }
}

struct ConversationPage: View {
    let peer: UUID
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @State private var draft = ""
    @State private var loaded = false

    var body: some View {
        let skater = library.visibleSkater(peer)
        NinaPage(skater?.profile.name ?? "Chat", ground: "CrewGround", editing: true) {
            if let skater, library.me?.reported(.conversation(peer)) != true {
                SkaterRow(skater: skater, detail: "Open skate profile")
                HStack(spacing: 3) {
                    NinaButton("Voice", icon: .phone, kind: .paper) { requestCall(.voice) }
                    NinaButton("Video", icon: .video, kind: .paper) { requestCall(.video) }
                }
                if !library.canContact(peer) {
                    NinaNotice(text: "Both skaters must follow each other to save a draft or open call waiting.")
                    if !library.follows(peer) {
                        NinaButton("Follow \(skater.profile.name)", icon: .crew) { flow.run { try library.toggleFollow(peer) } }
                    }
                }
                NinaField(title: "Message draft", value: $draft, lines: 5)
                NinaButton("Save draft", icon: .send) {
                    flow.run {
                        try library.saveDraft(to: peer, body: draft)
                        NinaKeyboard.dismiss()
                        flow.notice = "Draft saved."
                    }
                }
                .disabled(draft.cleaned.isEmpty)
                if library.me?.drafts.contains(where: { $0.peer == peer }) == true {
                    NinaButton("Discard saved draft", icon: .close, kind: .paper) {
                        flow.run {
                            try library.discardDraft(to: peer)
                            draft = ""
                            flow.notice = "Draft discarded."
                        }
                    }
                }
                NinaRow(title: "Report chat", detail: nil, icon: .flag) { flow.open(.report(.conversation(peer))) }
                NinaRow(title: "Block skater", detail: nil, icon: .close) { flow.open(.block(peer)) }
            } else {
                NinaEmpty(icon: .comment, title: "Chat unavailable", note: "")
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            draft = library.me?.drafts.first { $0.peer == peer }?.body ?? ""
        }
    }

    private func requestCall(_ kind: SkateCallKind) {
        guard library.canContact(peer) else {
            flow.notice = "Both skaters must follow each other before call waiting can open."
            return
        }
        flow.open(.call(peer, kind))
    }
}
