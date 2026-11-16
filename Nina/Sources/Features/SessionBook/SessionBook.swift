import SwiftUI

struct SessionBook: View {
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow

    var body: some View {
        NinaPage("Sessions", ground: "SessionsGround", root: true,
                 action: NinaAction(title: "Log tricks", icon: .add) { flow.open(.trick(nil, nil, nil)) }) {
            journalCover
            let attempts = (library.me?.attempts ?? []).sorted { $0.date > $1.date }
            let spots = library.me?.spots ?? []
            HStack {
                NinaHeading(text: "Spot book")
                Spacer()
                NinaButton("Add spot", icon: .spot, kind: .paper) { flow.open(.spotEditor(nil, nil)) }
            }
            if spots.isEmpty {
                NinaEmpty(icon: .ramp, title: "Keep your first spot", note: "Record its terrain, obstacles and access notes for your next session.")
            }
            ForEach(spots) { spot in
                let count = attempts.filter { $0.spotID == spot.id && $0.attempts > 0 }.count
                NinaRow(title: spot.name, detail: "\(spot.terrain.title) · \(spot.obstacle) · \(count) \(count == 1 ? "visit" : "visits")", icon: .spot) {
                    flow.open(.spot(spot.id))
                }
            }
            NinaHeading(text: "Trick log")
            if attempts.isEmpty {
                NinaEmpty(icon: .deck, title: "No tricks logged", note: "Pick a spot, set a landing goal and log your tries when you skate.")
            }
            ForEach(attempts) { attempt in
                TrickLedgerRow(attempt: attempt, spotName: spots.first(where: { $0.id == attempt.spotID })?.name)
            }
        }
    }

    private var journalCover: some View {
        let cover = library.me?.selectedCover
        let sessions = library.me?.attempts.filter { $0.attempts > 0 }.count ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(sessions) \(sessions == 1 ? "session" : "sessions") logged")
                .font(NinaTheme.heading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            NinaButton("Journal covers", icon: .grip, kind: .paper) { flow.open(.covers) }
        }
        .foregroundColor(NinaTheme.paper)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .padding(14)
        .background {
            if let cover {
                GeometryReader { geometry in
                    Image(cover.image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }
                .overlay(NinaTheme.ink.opacity(0.59))
                .accessibilityHidden(true)
            } else {
                NinaTheme.ink
            }
        }
    }
}

struct TrickLedgerRow: View {
    let attempt: TrickAttempt
    var spotName: String?
    @EnvironmentObject private var flow: NinaFlow

    var body: some View {
        Button {
            flow.open(.trick(attempt.id, attempt.spotID, attempt.referenceID))
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(attempt.date, format: .dateTime.month(.abbreviated))
                        .font(NinaTheme.caption)
                    Text(attempt.date, format: .dateTime.day())
                        .font(NinaTheme.card)
                        .monospacedDigit()
                }
                .foregroundColor(NinaTheme.paper)
                .padding(10)
                .background(NinaTheme.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attempt.trick).font(NinaTheme.card)
                    if let spotName { Text(spotName).font(NinaTheme.label) }
                    Text("\(attempt.stance.title) · \(attempt.progress.rawValue)").font(NinaTheme.caption)
                    Text("\(attempt.landings) landed / \(attempt.attempts) tries · Goal \(attempt.goal)")
                        .font(NinaTheme.caption)
                        .foregroundColor(NinaTheme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundColor(NinaTheme.ink)
            .background(NinaTheme.paper)
        }
        .buttonStyle(NinaPress())
    }
}

struct SpotPage: View {
    let id: UUID
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow

    var body: some View {
        let spot = library.me?.spots.first(where: { $0.id == id })
        NinaPage(spot?.name ?? "Spot", ground: "SessionsGround") {
            if let spot {
                VStack(alignment: .leading, spacing: 6) {
                    Text(spot.terrain.title + " / " + spot.condition.title).font(NinaTheme.label).foregroundColor(NinaTheme.muted)
                    Text(spot.obstacle).font(NinaTheme.heading)
                    if !spot.accessNotes.isEmpty { Text(spot.accessNotes) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(15)
                .background(NinaTheme.paper)
                NinaButton("Log tricks here", icon: .add) { flow.open(.trick(nil, id, spot.referenceID)) }
                NinaRow(title: "Skaters at this spot", detail: "Practice summaries skaters chose to share.", icon: .crew) {
                    flow.open(.crewAtSpot(spot.crewKey, spot.name))
                }
                if let line = spot.referenceID, let item = NinaConfiguration.line(line) {
                    NinaRow(title: item.title, detail: "Reference line", icon: .lines) { flow.open(.line(line)) }
                }
                NinaButton("Edit spot", icon: .edit, kind: .paper) { flow.open(.spotEditor(id, nil)) }
                NinaHeading(text: "Visits and plans")
                let visits = library.sessions(at: spot)
                if visits.isEmpty { NinaNotice(text: "Log tries here to keep a record of this spot.") }
                ForEach(visits) { TrickLedgerRow(attempt: $0) }
            } else {
                NinaEmpty(icon: .spot, title: "Spot unavailable", note: "")
            }
        }
    }
}
