import Foundation

extension NinaLibrary {
    func saveSpot(_ draft: SkateSpot) throws {
        var spot = draft
        spot.name = try spot.name.validatedText(label: "a spot name", limit: 60)
        spot.obstacle = try spot.obstacle.validatedText(label: "an obstacle", limit: 50)
        spot.accessNotes = try spot.accessNotes.validatedText(label: "access notes", limit: 280, required: false)
        try updateAccount { account in
            guard !account.spots.contains(where: { $0.id != spot.id && $0.crewKey == spot.crewKey }) else {
                throw NinaIssue("You already saved this spot.")
            }
            if let index = account.spots.firstIndex(where: { $0.id == spot.id }) {
                account.spots[index] = spot
            } else {
                account.spots.insert(spot, at: 0)
            }
        }
    }

    func removeSpot(_ id: UUID) throws {
        try updateAccount { account in
            guard !account.attempts.contains(where: { $0.spotID == id }) else {
                throw NinaIssue("Move or remove the trick logs for this spot first.")
            }
            account.spots.removeAll { $0.id == id }
        }
    }

    func saveAttempt(_ draft: TrickAttempt) throws {
        var attempt = draft
        attempt.trick = try attempt.trick.validatedText(label: "a trick", limit: 50)
        attempt.notes = try attempt.notes.validatedText(label: "practice notes", limit: 400, required: false)
        guard (0...500).contains(attempt.attempts), (0...attempt.attempts).contains(attempt.landings),
              (1...50).contains(attempt.goal), (0...480).contains(attempt.minutes) else {
            throw NinaIssue("Use 0–500 tries, landings within tries, a goal of 1–50 and 0–480 minutes.")
        }
        try updateAccount { account in
            guard account.spots.contains(where: { $0.id == attempt.spotID }) else {
                throw NinaIssue("Choose a spot before saving.")
            }
            if let index = account.attempts.firstIndex(where: { $0.id == attempt.id }) {
                account.attempts[index] = attempt
            } else {
                account.attempts.insert(attempt, at: 0)
            }
        }
    }

    func removeAttempt(_ id: UUID) throws {
        try updateAccount { $0.attempts.removeAll { $0.id == id } }
    }

    func sessions(at spot: SkateSpot) -> [TrickAttempt] {
        (me?.attempts ?? []).filter { $0.spotID == spot.id }.sorted { $0.date > $1.date }
    }

    func crewSessions(_ skater: SkaterAccount, at key: String? = nil) -> [TrickAttempt] {
        let spots = Set(skater.spots.filter { key == nil || $0.crewKey == key }.map(\.id))
        return skater.attempts.filter { $0.shareWithCrew && $0.attempts > 0 && spots.contains($0.spotID) }
    }

    func selectCover(_ cover: JournalCover) throws {
        try updateAccount { account in
            if !account.covers.contains(cover) {
                guard account.balance >= cover.cost else { throw NinaIssue("You need \(cover.cost) Grip for this cover.") }
                account.grip.append(GripEntry(id: "cover-" + cover.rawValue, label: cover.title, amount: -cover.cost))
                account.covers.insert(cover)
            }
            account.selectedCover = cover
        }
    }

    func clearCover() throws { try updateAccount { $0.selectedCover = nil } }
}
