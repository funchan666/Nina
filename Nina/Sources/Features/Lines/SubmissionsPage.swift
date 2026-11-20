import SwiftUI

struct SubmissionEditor: View {
    let id: UUID?
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @State private var original: LineSubmission?
    @State private var title = ""
    @State private var caption = ""
    @State private var selection: SkateSelection?
    @State private var busy = false
    @State private var loaded = false
    @State private var confirmingDeletion = false
    @State private var transfer: Task<Void, Never>?

    var body: some View {
        NinaPage(id == nil ? "Post a line" : "Edit submission", ground: "LinesGround", editing: true) {
            if id == nil || (loaded && original != nil) {
                NinaField(title: "Title", value: $title)
                NinaField(title: "Caption", value: $caption, lines: 3)
                attachmentSection
                NinaNotice(text: "Only you can view items in your review queue.")
                NinaButton(busy ? "Saving…" : "Save for review", icon: .check, action: save)
                    .disabled(busy || title.cleaned.isEmpty || (selection == nil && original == nil))
                if let id {
                    if confirmingDeletion {
                        NinaNotice(text: "Remove this submission and its media?")
                        NinaButton("Remove submission", kind: .destructive) {
                            flow.run {
                                try library.deleteSubmission(id)
                                flow.back()
                                flow.notice = "Submission removed."
                            }
                        }
                        .disabled(busy)
                        NinaButton("Keep submission", kind: .paper) { confirmingDeletion = false }
                    } else {
                        NinaButton("Remove submission", kind: .paper) { confirmingDeletion = true }.disabled(busy)
                    }
                }
            } else if loaded {
                NinaNotice(text: "This submission is unavailable.", error: true)
            }
        }
        .onAppear(perform: load)
        .onDisappear { transfer?.cancel() }
    }

    private var attachmentSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            NinaHeading(text: "Skate media")
            if let selection {
                if selection.type == .photo {
                    SkateStill(url: selection.url, label: "Selected skate photo", fill: false, pixels: 740)
                        .frame(height: 185)
                } else {
                    NinaNotice(text: "Film selected")
                }
                NinaButton("Clear selection", icon: .close, kind: .paper) { self.selection = nil }.disabled(busy)
            } else if let original {
                NinaButton("View attached media", icon: .expand, kind: .paper) { flow.open(.submissionViewer(original.id)) }
            }
            Group {
                SkatePickerButton(source: .photos, title: "Choose photo or film", icon: .deck, allowsVideo: true,
                                  pick: useSelection, report: failure)
                SkatePickerButton(source: .picture, title: "Take a photo", icon: .camera,
                                  pick: useSelection, report: failure)
                SkatePickerButton(source: .movie, title: "Record a film", icon: .video,
                                  pick: useSelection, report: failure)
                if flow.notice?.contains("Settings") == true {
                    NinaButton("Open iPhone Settings", icon: .settings, kind: .paper, action: NinaDeviceSettings.open)
                }
            }
            .disabled(busy)
        }
    }

    private func useSelection(_ item: SkateSelection) {
        guard !busy else { return }
        selection = item
        flow.notice = nil
    }

    private func failure(_ message: String) { flow.notice = message }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let id, let post = library.me?.submissions.first(where: { $0.id == id }) else { return }
        original = post
        title = post.title
        caption = post.caption
    }

    private func save() {
        guard !busy, let owner = library.activeID else { return }
        NinaKeyboard.dismiss()
        busy = true
        let chosen = selection
        let source = original
        let title = self.title
        let caption = self.caption
        let origin = flow.position
        transfer = Task {
            var imported: SkateAttachment?
            defer { busy = false; transfer = nil }
            do {
                if let chosen { imported = try await NinaFiles.importMedia(chosen, owner: owner) }
                try Task.checkCancellation()
                guard let attachment = imported ?? source?.attachment else { throw NinaIssue("Choose a photo or film.") }
                let post = LineSubmission(id: source?.id ?? UUID(), title: title, caption: caption, attachment: attachment,
                                          createdAt: source?.createdAt ?? Date())
                try library.saveSubmission(post, owner: owner)
                if let previous = source?.attachment, previous != attachment {
                    NinaFiles.remove(previous, owner: owner)
                }
                if flow.position == origin {
                    flow.back()
                    flow.notice = "Saved for review."
                }
            } catch {
                if let imported { NinaFiles.remove(imported, owner: owner) }
                if !Task.isCancelled { failure((error as? NinaIssue)?.text ?? "Couldn't save this submission.") }
            }
        }
    }
}

struct SubmissionsPage: View {
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow

    var body: some View {
        NinaPage("Submissions", ground: "LinesGround",
                 action: NinaAction(title: "Post", icon: .add) { flow.open(.postEditor(nil)) }) {
            let posts = library.me?.submissions ?? []
            if posts.isEmpty { NinaEmpty(icon: .deck, title: "No submissions", note: "Save your first photo or film for review.") }
            ForEach(posts) { post in
                VStack(alignment: .leading, spacing: 5) {
                    Text(post.status.rawValue).font(NinaTheme.caption).foregroundColor(NinaTheme.muted)
                    Text(post.title).font(NinaTheme.card)
                    if !post.caption.isEmpty { Text(post.caption) }
                    HStack {
                        NinaButton("View media", icon: .expand, kind: .ink) { flow.open(.submissionViewer(post.id)) }
                        NinaButton("Edit", icon: .edit, kind: .text) { flow.open(.postEditor(post.id)) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(13)
                .background(NinaTheme.paper)
            }
        }
    }
}

struct SubmissionViewer: View {
    let id: UUID
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow

    var body: some View {
        let post = library.me?.submissions.first { $0.id == id }
        LineMediaStage(title: post?.title ?? "Submission", close: flow.back) { geometry in
            if let post, let owner = library.activeID {
                let attachment = post.attachment
                if attachment.type == .video {
                    SkateFilm(id: attachment.file, title: post.title, url: NinaFiles.mediaURL(attachment.file, owner: owner),
                              poster: attachment.posterFile.flatMap { NinaFiles.mediaURL($0, owner: owner) },
                              height: max(44, geometry.size.height - 48))
                } else {
                    SkateStill(url: NinaFiles.mediaURL(attachment.file, owner: owner), label: post.title, fill: false, pixels: 1700)
                }
            } else {
                NinaEmpty(icon: .deck, title: "Submission unavailable", note: "")
            }
        }
    }
}
