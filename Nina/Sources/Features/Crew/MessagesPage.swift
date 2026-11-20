import SwiftUI

private enum MessageSection: String, CaseIterable {
    case chats = "Chats", drafts = "Drafts", activity = "Activity"
}

private struct ChatThread: Identifiable {
    let peer: SkaterAccount
    let message: CrewMessage
    var id: UUID { peer.id }
}

struct MessagesPage: View {
    var root = false
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @State private var section = MessageSection.chats

    private var threads: [ChatThread] {
        guard let owner = library.activeID else { return [] }
        var latest: [UUID: CrewMessage] = [:]
        for message in library.archive.messages where message.sender == owner || message.recipient == owner {
            let peer = message.sender == owner ? message.recipient : message.sender
            if latest[peer] == nil || latest[peer]!.date <= message.date { latest[peer] = message }
        }
        return latest.compactMap { id, message in
            guard let peer = library.visibleSkater(id), library.me?.reported(.conversation(id)) != true else { return nil }
            return ChatThread(peer: peer, message: message)
        }.sorted { $0.message.date > $1.message.date }
    }

    var body: some View {
        NinaPage("Inbox", ground: "CrewGround", root: root,
                 action: NinaAction(title: "Find skaters", icon: .add) { flow.select(.crew) }) {
            Text("Conversations, saved drafts and your skate updates.").foregroundColor(NinaTheme.muted)
            NinaChoices(choices: MessageSection.allCases, selection: $section) {
                $0 == .activity && library.unread > 0 ? "Activity (\(library.unread))" : $0.rawValue
            }
            switch section {
            case .chats: chats
            case .drafts: drafts
            case .activity: activity
            }
        }
    }

    private var chats: some View {
        VStack(alignment: .leading, spacing: 10) {
            if threads.isEmpty {
                NinaEmpty(icon: .comment, title: "Start with your crew", note: "Open a skater’s profile to start a conversation.")
                NinaButton("Explore Crew", icon: .crew) { flow.select(.crew) }
            }
            ForEach(threads) { thread in
                let unread = library.activity.contains { $0.kind == .message && $0.actor == thread.id && !$0.read }
                Button { flow.open(.conversation(thread.id)) } label: {
                    HStack(spacing: 12) {
                        SkaterAvatar(skater: thread.peer, edge: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(thread.peer.profile.name).font(NinaTheme.label)
                            Text((unread ? "Unread · " : "") + (thread.message.sender == library.activeID ? "You: " : "") + String(thread.message.body.prefix(90)))
                                .font(NinaTheme.body).foregroundColor(NinaTheme.muted).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundColor(NinaTheme.ink).multilineTextAlignment(.leading)
                    .padding(13).frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    .background(NinaTheme.paper).clipShape(RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(NinaPress())
            }
        }
    }

    private var drafts: some View {
        let drafts = (library.me?.drafts ?? []).filter {
            library.visibleSkater($0.peer) != nil && library.me?.reported(.conversation($0.peer)) != true
        }.sorted { $0.savedAt > $1.savedAt }
        return VStack(alignment: .leading, spacing: 8) {
            if drafts.isEmpty {
                NinaEmpty(icon: .comment, title: "No saved drafts", note: "Save a message when you want to finish it later.")
            }
            ForEach(drafts) { draft in
                if let peer = library.visibleSkater(draft.peer) {
                    NinaRow(title: peer.profile.name, detail: String(draft.body.prefix(90)), icon: .comment) {
                        flow.open(.conversation(peer.id))
                    }
                }
            }
        }
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 8) {
            if library.unread > 0 {
                NinaButton("Mark activity read", icon: .check, kind: .paper) { flow.run { try library.markActivityRead() } }
            }
            if library.activity.isEmpty {
                NinaEmpty(icon: .comment, title: "No activity yet", note: "Messages and updates from your profile and submissions will appear here.")
            }
            ForEach(library.activity) { event in
                switch event.kind {
                case .follow:
                    if let actor = event.actor.flatMap(library.visibleSkater) {
                        NinaRow(title: actor.profile.name + " followed you", detail: event.read ? nil : "Unread", icon: .crew) {
                            flow.open(.profile(actor.id))
                        }
                    }
                case .message:
                    if let actor = event.actor.flatMap(library.visibleSkater) {
                        NinaRow(title: "Message from " + actor.profile.name,
                                detail: (event.read ? "" : "Unread · ") + String(event.detail.prefix(90)), icon: .comment) {
                            flow.open(.conversation(actor.id))
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
    @Environment(\.ninaRouteVisible) private var visible
    @State private var draft = ""
    @State private var loaded = false
    @State private var shown = 50
    @State private var removing: UUID?
    @State private var showSafety = false

    private var available: Bool {
        library.visibleSkater(peer) != nil && library.me?.reported(.conversation(peer)) != true
    }

    var body: some View {
        ScrollViewReader { scroll in
            NinaPage(library.visibleSkater(peer)?.profile.name ?? "Chat", ground: "CrewGround", editing: true,
                     action: NinaAction(title: "Actions", icon: .more) { showSafety.toggle() }) {
                if let skater = library.visibleSkater(peer), available {
                    SkaterRow(skater: skater, detail: "Open skate profile")
                    if showSafety {
                        NinaRow(title: "Report chat", icon: .flag) { flow.open(.report(.conversation(peer))) }
                        NinaRow(title: "Block skater", icon: .close) { flow.open(.block(peer)) }
                    }
                    HStack(spacing: 8) {
                        NinaButton("Voice", icon: .phone, kind: .paper) { requestCall(.voice) }
                        NinaButton("Video", icon: .video, kind: .paper) { requestCall(.video) }
                    }
                    if !library.canContact(peer) {
                        NinaNotice(text: "Follow each other before sending messages or opening call waiting.")
                        if !library.follows(peer) {
                            NinaButton("Follow \(skater.profile.name)", icon: .crew) { flow.run { try library.toggleFollow(peer) } }
                        }
                    }
                    let messages = library.messages(with: peer)
                    if messages.count > shown {
                        NinaButton("Earlier messages", icon: .load, kind: .paper) { shown += 50 }
                    }
                    if messages.isEmpty {
                        NinaEmpty(icon: .comment, title: "Your conversation starts here", note: "Say something about the next session.")
                    }
                    ForEach(Array(messages.suffix(shown))) { message in bubble(message) }
                    if let removing {
                        NinaNotice(text: "Delete this message from the conversation?")
                        NinaButton("Delete message", kind: .destructive) {
                            flow.run { try library.removeMessage(removing); self.removing = nil }
                        }
                        NinaButton("Keep message", kind: .paper) { self.removing = nil }
                    }
                    composer.id("message-composer")
                } else {
                    NinaEmpty(icon: .comment, title: "Chat unavailable", note: "")
                }
            }
            .onAppear {
                if !loaded {
                    loaded = true
                    draft = library.me?.drafts.first { $0.peer == peer }?.body ?? ""
                }
                markRead()
                if visible { scroll.scrollTo("message-composer", anchor: .bottom) }
            }
            .onChange(of: visible) { current in if current { markRead() } }
            .onChange(of: library.unread) { _ in markRead() }
            .onChange(of: library.messages(with: peer).count) { _ in
                if visible { scroll.scrollTo("message-composer", anchor: .bottom) }
            }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            NinaField(title: "Message", value: $draft, lines: 3)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { sendButton; draftButton }
                VStack(alignment: .leading, spacing: 8) { sendButton; draftButton }
            }
            if library.me?.drafts.contains(where: { $0.peer == peer }) == true {
                NinaButton("Discard saved draft", icon: .close, kind: .text) {
                    flow.run {
                        try library.discardDraft(to: peer)
                        draft = ""
                        flow.notice = "Draft discarded."
                    }
                }
            }
        }
    }

    private var sendButton: some View {
        NinaButton("Send message", icon: .send) {
            flow.run {
                try library.sendMessage(to: peer, body: draft)
                draft = ""
                NinaKeyboard.dismiss()
            }
        }.disabled(draft.cleaned.isEmpty || !library.canContact(peer))
    }

    private var draftButton: some View {
        NinaButton("Save draft", kind: .paper) {
            flow.run {
                try library.saveDraft(to: peer, body: draft)
                NinaKeyboard.dismiss()
                flow.notice = "Draft saved."
            }
        }.disabled(draft.cleaned.isEmpty || !library.canContact(peer))
    }

    private func bubble(_ message: CrewMessage) -> some View {
        let own = message.sender == library.activeID
        return VStack(alignment: .leading, spacing: 6) {
            Text(message.body).font(NinaTheme.body).textSelection(.enabled)
            HStack(spacing: 8) {
                Text(message.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(NinaTheme.caption).foregroundColor(own ? NinaTheme.sage : NinaTheme.muted)
                if own {
                    NinaIconButton(title: "Delete your message", icon: .close, fg: NinaTheme.paper) { removing = message.id }
                }
            }
        }
        .foregroundColor(own ? NinaTheme.paper : NinaTheme.ink)
        .padding(.horizontal, 15).padding(.vertical, 10)
        .background(own ? NinaTheme.ink : NinaTheme.sage).clipShape(RoundedRectangle(cornerRadius: 17))
        .frame(maxWidth: .infinity, alignment: own ? .trailing : .leading)
    }

    private func markRead() {
        guard visible, available else { return }
        flow.run { try library.markConversationRead(peer) }
    }

    private func requestCall(_ kind: SkateCallKind) {
        guard library.canContact(peer) else {
            flow.notice = "Both skaters must follow each other before call waiting can open."
            return
        }
        flow.open(.call(peer, kind))
    }
}
