import Foundation

extension NinaLibrary {
    func comments(on line: String) -> [LineComment] {
        archive.comments.filter {
            $0.lineID == line && me?.reported(.comment($0.id)) != true && visibleSkater($0.authorID) != nil
        }.sorted { $0.date < $1.date }
    }

    func visibleLikes(on line: String) -> Int {
        archive.accounts.values.filter { $0.liked.contains(line) && visibleSkater($0.id) != nil }.count
    }

    func toggleLike(_ line: String) throws {
        try updateAccount { account in
            guard !account.reported(.line(line)) else { throw NinaIssue("This line is hidden.") }
            if account.liked.remove(line) == nil { account.liked.insert(line) }
        }
    }

    func toggleSave(_ line: String) throws {
        try updateAccount { account in
            guard !account.reported(.line(line)) else { throw NinaIssue("This line is hidden.") }
            if account.saved.remove(line) == nil { account.saved.insert(line) }
        }
    }

    func saveComment(on line: String, text: String, editing commentID: UUID?) throws {
        let author = try accountID()
        guard me?.reported(.line(line)) != true else { throw NinaIssue("This line is hidden.") }
        let body = try text.validatedText(label: "a comment", limit: 400)
        try commit { next in
            if let commentID {
                guard let index = next.comments.firstIndex(where: {
                    $0.id == commentID && $0.authorID == author && $0.lineID == line
                }) else { throw NinaIssue("This comment is unavailable.") }
                next.comments[index].body = body
            } else {
                next.comments.append(LineComment(lineID: line, authorID: author, body: body, date: Date()))
            }
        }
    }

    func deleteComment(_ id: UUID) throws {
        let author = try accountID()
        try commit { $0.comments.removeAll { $0.id == id && $0.authorID == author } }
    }

    func saveSubmission(_ draft: LineSubmission, owner: UUID) throws {
        let id = try accountID()
        guard id == owner else { throw NinaIssue("Switch back to the profile that owns this post.") }
        var post = draft
        post.title = try post.title.validatedText(label: "a title", limit: 60)
        post.caption = try post.caption.validatedText(label: "a caption", limit: 400, required: false)
        try commit { next in
            if let index = next.accounts[owner]?.submissions.firstIndex(where: { $0.id == post.id }) {
                next.accounts[owner]?.submissions[index] = post
            } else {
                next.accounts[owner]?.submissions.insert(post, at: 0)
                next.activity.insert(CrewEvent(owner: owner, actor: nil, kind: .submission, detail: post.title), at: 0)
            }
        }
    }

    func deleteSubmission(_ id: UUID) throws {
        let owner = try accountID()
        guard let post = me?.submissions.first(where: { $0.id == id }) else { return }
        try updateAccount { $0.submissions.removeAll { $0.id == id } }
        NinaFiles.remove(post.attachment, owner: owner)
    }
}
