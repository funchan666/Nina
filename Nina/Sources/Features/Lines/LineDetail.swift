import SwiftUI

struct LineDetail: View {
    let id: String
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @State private var text = ""
    @State private var editing: UUID?

    var body: some View {
        NinaPage(NinaConfiguration.line(id)?.title ?? "Line", ground: "LinesGround", editing: true) {
            if let item = NinaConfiguration.line(id), library.me?.reported(.line(id)) != true {
                media(item)
                Text(item.collection.title + " · Collection")
                    .foregroundColor(NinaTheme.muted).font(NinaTheme.label)
                actions
                if item.collection.terrain != nil {
                    NinaRow(title: "Practice this line", detail: "Use it as a reference in your trick log.", icon: .sessions) {
                        flow.open(.trick(nil, nil, id))
                    }
                    NinaRow(title: "Add a related spot", detail: "Keep the terrain and reference together.", icon: .spot) {
                        flow.open(.spotEditor(nil, id))
                    }
                }
                comments
            } else {
                NinaEmpty(icon: .flag, title: "Line unavailable", note: "Return to the collection to continue browsing.")
            }
        }
    }

    @ViewBuilder private func media(_ item: LineMedia) -> some View {
        if item.type == .video {
            SkateFilm(id: id, title: item.title, url: NinaConfiguration.objectURL(item.path),
                      poster: NinaConfiguration.objectURL(item.stillPath), height: 320,
                      expand: { flow.open(.lineViewer(id)) }, report: { flow.open(.report(.line(id))) })
        } else {
            SkateStill(url: NinaConfiguration.objectURL(item.path), label: item.title, retryable: true)
                .aspectRatio(min(1.62, max(0.8, item.aspectRatio)), contentMode: .fit)
            NinaButton("View photo", icon: .expand, kind: .paper) { flow.open(.lineViewer(id)) }
        }
    }

    private var actions: some View {
        let liked = library.me?.liked.contains(id) == true
        let saved = library.me?.saved.contains(id) == true
        let likes = library.visibleLikes(on: id)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                NinaButton(liked ? "Liked (\(likes))" : "Like (\(likes))", icon: liked ? .liked : .like, kind: .paper) {
                    flow.run { try library.toggleLike(id) }
                }
                NinaButton(saved ? "Saved" : "Save", icon: saved ? .saved : .save, kind: .paper) {
                    flow.run { try library.toggleSave(id) }
                }
                NinaButton("Report", icon: .flag, kind: .paper) { flow.open(.report(.line(id))) }
            }
        }
    }

    private var comments: some View {
        VStack(alignment: .leading, spacing: 8) {
            NinaHeading(text: "Comments")
            let thread = library.comments(on: id)
            if thread.isEmpty { NinaNotice(text: "Start the discussion about this line.") }
            ForEach(thread) { item in
                VStack(alignment: .leading, spacing: 4) {
                    if let person = library.visibleSkater(item.authorID) {
                        NinaButton(person.profile.name, icon: .avatar, kind: .text) {
                            flow.open(.profile(person.id))
                        }
                    }
                    Text(item.body).font(NinaTheme.body)
                    if item.authorID == library.activeID {
                        HStack {
                            NinaButton("Edit", icon: .edit, kind: .text) {
                                text = item.body
                                editing = item.id
                            }
                            NinaButton("Delete", kind: .text) {
                                flow.run {
                                    try library.deleteComment(item.id)
                                    if editing == item.id {
                                        editing = nil
                                        text = ""
                                    }
                                }
                            }
                        }
                    } else {
                        HStack {
                            NinaButton("Report", icon: .flag, kind: .text) { flow.open(.report(.comment(item.id))) }
                            NinaButton("Block skater", kind: .text) { flow.open(.block(item.authorID)) }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NinaTheme.paper)
            }
            NinaField(title: editing == nil ? "Add a comment" : "Edit your comment", value: $text, lines: 3)
            HStack {
                NinaButton(editing == nil ? "Post comment" : "Save comment", icon: .send) {
                    flow.run {
                        try library.saveComment(on: id, text: text, editing: editing)
                        text = ""
                        editing = nil
                        NinaKeyboard.dismiss()
                    }
                }
                .disabled(text.cleaned.isEmpty)
                if editing != nil {
                    NinaButton("Cancel", kind: .paper) {
                        editing = nil
                        text = ""
                    }
                }
            }
        }
    }
}

struct LineViewer: View {
    let id: String
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow

    var body: some View {
        LineMediaStage(title: NinaConfiguration.line(id)?.title ?? "Line", close: flow.back) { geometry in
            if let item = NinaConfiguration.line(id), library.me?.reported(.line(id)) != true {
                if item.type == .video {
                    SkateFilm(id: id, title: item.title, url: NinaConfiguration.objectURL(item.path),
                              poster: NinaConfiguration.objectURL(item.stillPath),
                              height: max(44, geometry.size.height - 48),
                              report: { flow.open(.report(.line(id))) })
                } else {
                    SkateStill(url: NinaConfiguration.objectURL(item.path), label: item.title, fill: false,
                               retryable: true, pixels: 1800)
                }
            } else {
                NinaEmpty(icon: .flag, title: "Line hidden", note: "")
            }
        }
    }
}
