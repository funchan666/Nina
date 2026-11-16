import SwiftUI

struct CrewIndex: View {
    var spotKey: String?
    var spotName: String?
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @State private var query = ""

    private var skaters: [SkaterAccount] {
        library.crew.filter { member in
            (spotKey == nil || !library.crewSessions(member, at: spotKey).isEmpty) &&
            (query.cleaned.isEmpty || member.profile.name.localizedCaseInsensitiveContains(query.cleaned))
        }
    }

    var body: some View {
        NinaPage(spotName ?? "Crew", ground: "CrewGround", root: spotKey == nil, editing: true,
                 action: spotKey == nil ? NinaAction(title: library.unread == 0 ? "Messages" : "Messages (\(library.unread))",
                                                     icon: .comment) { flow.open(.messages) } : nil) {
            if spotKey == nil, let me = library.me {
                NinaRow(title: "Your skate profile", detail: me.profile.name, icon: .avatar) { flow.open(.profile(me.id)) }
                NinaHeading(text: "Find skaters")
            } else {
                Text("Skaters with shared sessions here.").foregroundColor(NinaTheme.muted)
            }
            if !library.crew.isEmpty { NinaField(title: "Find by name", value: $query) }
            if skaters.isEmpty {
                NinaEmpty(icon: .crew, title: spotKey == nil ? "No other skaters here yet" : "No shared sessions here",
                          note: query.cleaned.isEmpty ? "Shared sessions connect skaters through a spot." : "Try a different name.")
            } else {
                ForEach(skaters) { member in
                    let sessions = library.crewSessions(member, at: spotKey)
                    SkaterRow(skater: member, detail: sessions.isEmpty ? member.profile.stance.title :
                                "\(member.profile.stance.title) · \(sessions.count) shared \(sessions.count == 1 ? "session" : "sessions")")
                }
            }
        }
    }
}

struct SkaterRow: View {
    let skater: SkaterAccount
    var detail: String?
    @EnvironmentObject private var flow: NinaFlow

    var body: some View {
        Button {
            flow.open(.profile(skater.id))
        } label: {
            HStack(spacing: 10) {
                SkaterAvatar(skater: skater, edge: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(skater.profile.name).font(NinaTheme.label)
                    Text(detail ?? skater.profile.stance.title).font(NinaTheme.caption).foregroundColor(NinaTheme.muted)
                }
                Spacer(minLength: 0)
            }
            .foregroundColor(NinaTheme.ink)
            .multilineTextAlignment(.leading)
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .background(NinaTheme.paper)
        }
        .buttonStyle(NinaPress())
    }
}

struct SkaterAvatar: View {
    let skater: SkaterAccount
    let edge: CGFloat

    var body: some View {
        Group {
            if let photo = skater.profile.avatar,
               let url = NinaFiles.mediaURL(photo.file, owner: skater.id) {
                SkateStill(url: url, label: "Profile photo", pixels: 280)
            } else {
                InkGlyph(ink: .avatar, size: edge * 0.66)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(NinaTheme.grip)
            }
        }
        .frame(width: edge, height: edge)
        .accessibilityHidden(true)
    }
}

struct SkaterPage: View {
    let id: UUID
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @State private var showActions = false

    var body: some View {
        let skater = library.visibleSkater(id)
        let isSelf = id == library.activeID
        NinaPage(skater?.profile.name ?? "Skater", ground: "CrewGround",
                 action: isSelf ? NinaAction(title: "Edit", icon: .edit) { flow.open(.profileEditor) } : nil) {
            if let skater {
                identity(skater)
                if isSelf {
                    myJournal(skater)
                } else {
                    contact(skater)
                    sharedWork(skater)
                }
            } else {
                NinaEmpty(icon: .avatar, title: "Profile unavailable", note: "")
            }
        }
    }

    private func identity(_ skater: SkaterAccount) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                SkaterAvatar(skater: skater, edge: 80)
                VStack(alignment: .leading, spacing: 5) {
                    Text(skater.profile.stance.title + " stance").font(NinaTheme.card)
                    if !skater.profile.bio.isEmpty { Text(skater.profile.bio) }
                }
                Spacer(minLength: 0)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    NinaButton("Followers (\(library.relations(for: id, incoming: true).count))", icon: .crew, kind: .paper) {
                        flow.open(.relationships(id, true))
                    }
                    NinaButton("Following (\(library.relations(for: id, incoming: false).count))", kind: .paper) {
                        flow.open(.relationships(id, false))
                    }
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NinaTheme.paper)
    }

    private func myJournal(_ skater: SkaterAccount) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NinaHeading(text: "Skate record")
            let visits = skater.attempts.filter { $0.attempts > 0 }
            NinaNotice(text: "\(skater.spots.count) saved \(skater.spots.count == 1 ? "spot" : "spots") · \(visits.count) logged \(visits.count == 1 ? "session" : "sessions")")
            NinaRow(title: "Open your sessions", detail: nil, icon: .sessions) { flow.select(.sessions) }
            NinaRow(title: "Your submissions", detail: "\(skater.submissions.count) awaiting review", icon: .deck) { flow.open(.submissions) }
            NinaRow(title: "Wallet", detail: "\(skater.balance) Grip", icon: .grip) { flow.open(.wallet) }
            NinaRow(title: "Settings", detail: nil, icon: .settings) { flow.open(.settings) }
            NinaHeading(text: "Saved lines")
            let saved = NinaConfiguration.lines.filter { skater.saved.contains($0.id) && !skater.reported(.line($0.id)) }
            if saved.isEmpty { NinaNotice(text: "Save a line to return to it later.") }
            ForEach(saved) { item in
                NinaRow(title: item.title, detail: item.collection.title, icon: .saved) { flow.open(.line(item.id)) }
            }
        }
    }

    private func contact(_ skater: SkaterAccount) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 5) {
                NinaButton(library.follows(id) ? "Unfollow" : "Follow", icon: .crew) {
                    flow.run { try library.toggleFollow(id) }
                }
                NinaButton("Chat", icon: .comment, kind: .paper) { flow.open(.conversation(id)) }
                NinaIconButton(title: "More profile actions", icon: .more, bg: NinaTheme.paper) { showActions.toggle() }
            }
            if showActions {
                NinaRow(title: "Report profile", detail: nil, icon: .flag) { flow.open(.report(.skater(id))) }
                NinaRow(title: "Block \(skater.profile.name)", detail: nil, icon: .close) { flow.open(.block(id)) }
            }
        }
    }

    private func sharedWork(_ skater: SkaterAccount) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            NinaHeading(text: "Shared sessions")
            let sessions = library.crewSessions(skater).sorted { $0.date > $1.date }
            if sessions.isEmpty { NinaNotice(text: "This skater hasn’t shared a session.") }
            ForEach(sessions) { entry in
                let spotName = skater.spots.first { $0.id == entry.spotID }?.name
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.trick).font(NinaTheme.card)
                    Text([spotName, entry.stance.title, entry.progress.rawValue].compactMap { $0 }.joined(separator: " · "))
                    Text("\(entry.landings) landed / \(entry.attempts) tries").font(NinaTheme.caption)
                    if let reference = entry.referenceID, let item = NinaConfiguration.line(reference),
                       library.me?.reported(.line(reference)) != true {
                        NinaButton(item.title, icon: .lines, kind: .text) { flow.open(.line(item.id)) }
                    }
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NinaTheme.paper)
            }
        }
    }
}

struct RelationshipsPage: View {
    let id: UUID
    let incoming: Bool
    @EnvironmentObject private var library: NinaLibrary

    var body: some View {
        NinaPage(incoming ? "Followers" : "Following", ground: "CrewGround") {
            let rows = library.visibleSkater(id) == nil ? [] : library.relations(for: id, incoming: incoming)
            if rows.isEmpty { NinaEmpty(icon: .crew, title: "No skaters to show", note: "") }
            ForEach(rows) { SkaterRow(skater: $0) }
        }
    }
}
