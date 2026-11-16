import SwiftUI

struct SpotEditor: View {
    let id: UUID?
    let referenceID: String?
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @State private var name = ""
    @State private var obstacle = ""
    @State private var access = ""
    @State private var terrain = SkateTerrain.street
    @State private var condition = SurfaceCondition.smooth
    @State private var loaded = false
    @State private var existing: SkateSpot?
    @State private var confirm = false

    var body: some View {
        NinaPage(id == nil ? "Save a spot" : "Edit spot", ground: "SessionsGround", editing: true) {
            if id == nil || existing != nil {
                NinaField(title: "Spot name", value: $name)
                NinaField(title: "Obstacle or feature", value: $obstacle)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Terrain").font(NinaTheme.label)
                    NinaChoices(choices: SkateTerrain.allCases, selection: $terrain, label: \.title)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Surface").font(NinaTheme.label)
                    NinaChoices(choices: SurfaceCondition.allCases, selection: $condition, label: \.title)
                }
                NinaField(title: "Access notes", value: $access, lines: 3)
                if let line = existing?.referenceID ?? referenceID, let item = NinaConfiguration.line(line) {
                    NinaNotice(text: "Reference · \(item.title)")
                }
                NinaButton("Save spot", icon: .check, action: save).disabled(name.cleaned.isEmpty || obstacle.cleaned.isEmpty)
                if let id {
                    if confirm {
                        NinaNotice(text: "Remove this spot from your book?")
                        NinaButton("Remove spot", kind: .destructive) {
                            flow.run {
                                try library.removeSpot(id)
                                flow.back()
                                flow.notice = "Spot removed."
                            }
                        }
                        NinaButton("Keep spot", kind: .paper) { confirm = false }
                    } else {
                        NinaButton("Remove spot", kind: .paper) { confirm = true }
                    }
                }
            } else if loaded {
                NinaNotice(text: "This spot is no longer in your book.", error: true)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let id, let spot = library.me?.spots.first(where: { $0.id == id }) {
            existing = spot
            name = spot.name
            terrain = spot.terrain
            obstacle = spot.obstacle
            condition = spot.condition
            access = spot.accessNotes
        } else if let referenceID, let item = NinaConfiguration.line(referenceID), let terrain = item.collection.terrain {
            self.terrain = terrain
        }
    }

    private func save() {
        flow.run {
            let draft = SkateSpot(id: existing?.id ?? UUID(), name: name, terrain: terrain, obstacle: obstacle,
                                  condition: condition, accessNotes: access, referenceID: existing?.referenceID ?? referenceID,
                                  createdAt: existing?.createdAt ?? Date())
            try library.saveSpot(draft)
            flow.back()
            flow.notice = "Spot saved."
        }
    }
}

struct TrickEditor: View {
    let id: UUID?
    let spotID: UUID?
    let referenceID: String?

    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @State private var selected: UUID?
    @State private var trick = ""
    @State private var stance = SkateStance.regular
    @State private var tries = "0"
    @State private var landings = "0"
    @State private var goal = "3"
    @State private var minutes = "0"
    @State private var notes = ""
    @State private var share = false
    @State private var loaded = false
    @State private var confirm = false
    @State private var original: TrickAttempt?

    var body: some View {
        NinaPage(id == nil ? "Log tricks" : "Edit trick log", ground: "SessionsGround", editing: true) {
            let spots = library.me?.spots ?? []
            if spots.isEmpty {
                NinaEmpty(icon: .spot, title: "Add a spot first", note: "A trick log needs a spot so you can return to the same terrain.")
                NinaButton("Save a spot", icon: .add) { flow.open(.spotEditor(nil, referenceID)) }
            } else if id == nil || original != nil {
                Text("Where did you skate?").font(NinaTheme.label)
                NinaChoices(choices: spots.map { Optional($0.id) }, selection: $selected) { choice in
                    spots.first { $0.id == choice }?.name ?? "Spot"
                }
                NinaField(title: "Trick", value: $trick)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Stance").font(NinaTheme.label)
                    NinaChoices(choices: SkateStance.allCases, selection: $stance, label: \.title)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 7)], alignment: .leading, spacing: 8) {
                    NinaField(title: "Tries", value: $tries, keyboard: .numberPad)
                    NinaField(title: "Landed", value: $landings, keyboard: .numberPad)
                    NinaField(title: "Landing goal", value: $goal, keyboard: .numberPad)
                    NinaField(title: "Minutes", value: $minutes, keyboard: .numberPad)
                }
                NinaField(title: "Practice notes", value: $notes, lines: 4)
                NinaCheck(title: "Show session summary in Crew", enabled: $share)
                if let line = original?.referenceID ?? referenceID, let item = NinaConfiguration.line(line) {
                    NinaNotice(text: "Reference · \(item.title)")
                }
                NinaButton("Save trick log", icon: .check, action: save).disabled(trick.cleaned.isEmpty)
                if let id {
                    NinaButton("Log another session", icon: .add, kind: .paper) {
                        flow.open(.trick(nil, selected ?? spotID, original?.referenceID ?? referenceID))
                    }
                    deleteAction(id)
                }
            } else if loaded {
                NinaNotice(text: "This trick log is unavailable.", error: true)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let id, let attempt = library.me?.attempts.first(where: { $0.id == id }) {
            original = attempt
            selected = attempt.spotID
            trick = attempt.trick
            stance = attempt.stance
            tries = String(attempt.attempts)
            landings = String(attempt.landings)
            goal = String(attempt.goal)
            minutes = String(attempt.minutes)
            notes = attempt.notes
            share = attempt.shareWithCrew
        } else {
            selected = spotID ?? library.me?.spots.first?.id
            stance = library.me?.profile.stance ?? .regular
        }
    }

    private func save() {
        flow.run {
            guard let spot = selected ?? library.me?.spots.first?.id else {
                throw NinaIssue("Choose a spot.")
            }
            guard let tries = Int(tries.cleaned), let landings = Int(landings.cleaned),
                  let goal = Int(goal.cleaned), let minutes = Int(minutes.cleaned) else {
                throw NinaIssue("Enter whole numbers for tries, landings, goal and minutes.")
            }
            let work = TrickAttempt(id: original?.id ?? UUID(), spotID: spot, trick: trick, stance: stance,
                                    attempts: tries, landings: landings, goal: goal, minutes: minutes, notes: notes,
                                    referenceID: original?.referenceID ?? referenceID, shareWithCrew: share,
                                    date: original?.date ?? Date())
            try library.saveAttempt(work)
            flow.back()
            flow.notice = work.attempts == 0 ? "Practice plan saved." : "Session logged."
        }
    }

    @ViewBuilder private func deleteAction(_ id: UUID) -> some View {
        if confirm {
            NinaNotice(text: "Remove this trick log?")
            NinaButton("Remove log", kind: .destructive) {
                flow.run { try library.removeAttempt(id); flow.back(); flow.notice = "Trick log removed." }
            }
            NinaButton("Keep log", kind: .paper) { confirm = false }
        } else {
            NinaButton("Remove log", kind: .paper) { confirm = true }
        }
    }
}
