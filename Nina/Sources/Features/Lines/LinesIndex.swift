import SwiftUI

private enum LinesFilter: String, CaseIterable {
    case all = "All"
    case street = "Street"
    case park = "Park"
    case flat = "Flatground"
    case offboard = "Off the Board"

    var collection: LineCollection? {
        switch self {
        case .all: return nil
        case .street: return .street
        case .park: return .park
        case .flat: return .flat
        case .offboard: return .offboard
        }
    }
}

struct LinesIndex: View {
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @State private var filter = LinesFilter.all
    @State private var revision = 0

    private var results: [LineMedia] {
        NinaConfiguration.lines.filter { item in
            (filter.collection == nil || filter.collection == item.collection) && library.me?.reported(.line(item.id)) != true
        }
    }

    var body: some View {
        NinaPage("Lines", ground: "LinesGround", root: true,
                 action: NinaAction(title: "Post", icon: .add) { flow.open(.postEditor(nil)) }) {
            if NinaConfiguration.media == nil {
                offline
            } else {
                NinaChoices(choices: LinesFilter.allCases, selection: $filter, label: \.rawValue)
                if let feature = results.first {
                    LineTile(item: feature, layout: .feature, revision: revision)
                    collection(excluding: feature.id)
                } else {
                    NinaEmpty(icon: .ramp, title: "No lines in this collection", note: "Try another terrain.")
                }
                NinaButton("Refresh lines", icon: .load, kind: .paper) { revision += 1 }
            }
        }
    }

    private var offline: some View {
        VStack(alignment: .leading, spacing: 12) {
            InkGlyph(ink: .lines, size: 78, color: NinaTheme.grip)
            Text("Skate films and photos")
                .font(NinaTheme.heading)
                .accessibilityAddTraits(.isHeader)
            Text("The collection is unavailable right now.")
                .font(NinaTheme.body)
            NinaButton("Open your skate journal", icon: .sessions) { flow.select(.sessions) }
        }
        .foregroundColor(NinaTheme.paper)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(19)
        .background(NinaTheme.ink)
    }

    @ViewBuilder private func collection(excluding feature: String) -> some View {
        let films = results.filter { $0.type == .video && $0.id != feature }
        let photos = results.filter { $0.type == .photo && $0.id != feature }
        if !films.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                NinaHeading(text: "Skate films")
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 9) {
                        ForEach(films) { item in
                            LineTile(item: item, layout: .strip, revision: revision)
                                .frame(width: 144)
                        }
                    }
                }
            }
        }
        if !photos.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                NinaHeading(text: filter == .offboard ? "Around the session" : "Contact sheet")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 134), spacing: 8, alignment: .top)],
                          alignment: .leading, spacing: 13) {
                    ForEach(photos) { LineTile(item: $0, layout: .grid, revision: revision) }
                }
            }
        }
    }
}

private struct LineTile: View {
    enum Layout { case feature, strip, grid }

    let item: LineMedia
    let layout: Layout
    let revision: Int
    @EnvironmentObject private var flow: NinaFlow

    var body: some View {
        Button {
            flow.open(.line(item.id))
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                SkateStill(url: NinaConfiguration.objectURL(item.stillPath), label: item.title,
                           pixels: layout == .feature ? 1280 : 540, revision: revision)
                    .aspectRatio(layout == .feature ? 1.02 : layout == .strip ? 0.78 : 1.12, contentMode: .fit)
                    .overlay(alignment: .bottomTrailing) {
                        if item.type == .video {
                            HStack(spacing: 5) {
                                InkGlyph(ink: .play, size: 15, color: NinaTheme.paper)
                                if let seconds = item.duration {
                                    Text(timeText(seconds)).font(NinaTheme.caption).foregroundColor(NinaTheme.paper)
                                }
                            }
                            .padding(6)
                            .background(NinaTheme.ink)
                            .padding(6)
                        }
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.collection.title)
                        .font(NinaTheme.caption)
                        .foregroundColor(layout == .feature ? NinaTheme.grip : NinaTheme.muted)
                    Text(item.title).font(layout == .feature ? NinaTheme.heading : NinaTheme.label)
                        .foregroundColor(layout == .feature ? NinaTheme.paper : NinaTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(layout == .feature ? 14 : 8)
            }
            .background(layout == .feature ? NinaTheme.ink : NinaTheme.paper)
        }
        .buttonStyle(NinaPress())
        .accessibilityLabel(Text("\(item.title), \(item.collection.title), \(item.type == .video ? "film" : "photo")"))
    }
}
