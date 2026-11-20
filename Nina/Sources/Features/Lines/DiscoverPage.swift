import SwiftUI

struct DiscoverPage: View {
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow
    @State private var query = ""
    @State private var filter = LinesFilter.all
    @State private var count = 12

    private var results: [LineMedia] {
        NinaConfiguration.lines.filter { item in
            library.me?.reported(.line(item.id)) != true &&
            (filter.collection == nil || filter.collection == item.collection) &&
            (filter != .saved || library.me?.saved.contains(item.id) == true) &&
            (query.cleaned.isEmpty || (item.title + " " + item.collection.title).localizedCaseInsensitiveContains(query.cleaned))
        }
    }

    var body: some View {
        NinaPage("Discover", ground: "LinesGround", root: true,
                 action: NinaAction(title: "Post", icon: .add) { flow.open(.postEditor(nil)) }) {
            Text("Hi, \(library.me?.profile.name ?? "Skater").").font(NinaTheme.label).foregroundColor(NinaTheme.muted)
            sessionEntry
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    NinaHeading(text: "Find your next line")
                    Spacer(minLength: 6)
                    galleryButton
                }
                VStack(alignment: .leading, spacing: 4) {
                    NinaHeading(text: "Find your next line")
                    galleryButton
                }
            }
            NinaField(title: "Search photos and clips", value: $query)
            NinaChoices(choices: LinesFilter.allCases, selection: $filter) { $0 == .all ? "For you" : $0.rawValue }
            if results.isEmpty {
                NinaEmpty(icon: .lines, title: filter == .saved ? "No saved lines here" : "No lines found",
                          note: filter == .saved ? "Save a photo or clip to find it again." : "Try a different name or terrain.")
                NinaButton("Show all lines", kind: .paper) { query = ""; filter = .all }
            }
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(Array(results.prefix(count))) { item in DiscoverLine(item: item) }
            }
            if count < results.count {
                NinaButton("Show more lines", icon: .load, kind: .paper, wide: true) { count += 12 }
            }
            NinaButton("Crew rules", kind: .text) { flow.open(.policy(.rules)) }
        }
        .onChange(of: filter) { _ in count = 12 }
        .onChange(of: query) { _ in count = 12 }
    }

    private var galleryButton: some View {
        NinaButton("View gallery", kind: .text) { flow.open(.collection) }
    }

    private var sessionEntry: some View {
        Button { flow.select(.sessions) } label: {
            ZStack(alignment: .bottomLeading) {
                GeometryReader { geometry in
                    Image("CrewSession").resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }
                NinaTheme.ink.opacity(0.25)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Make it a\nskate day.").font(NinaTheme.heading)
                    Text("Open your sessions").font(NinaTheme.label)
                }
                .foregroundColor(NinaTheme.paper).padding(20)
            }
            .frame(height: 206).clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(NinaPress()).accessibilityLabel("Make it a skate day. Open your sessions")
    }
}

private struct DiscoverLine: View {
    let item: LineMedia
    @EnvironmentObject private var library: NinaLibrary
    @EnvironmentObject private var flow: NinaFlow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.collection.title + " · " + (item.type == .video ? "Film" : "Photo"))
                        .font(NinaTheme.caption).foregroundColor(NinaTheme.muted)
                    Text(item.title).font(NinaTheme.card).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                NinaIconButton(title: "Report " + item.title, icon: .flag) { flow.open(.report(.line(item.id))) }
            }.padding(14)
            Button { flow.open(.line(item.id)) } label: {
                SkateStill(url: NinaConfiguration.objectURL(item.stillPath), label: item.title, pixels: 1200)
                    .aspectRatio(min(1.5, max(0.8, item.aspectRatio)), contentMode: .fit)
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 6) {
                            if item.type == .video { InkGlyph(ink: .play, size: 19, color: NinaTheme.paper) }
                            Text(item.type == .video ? "Watch clip" : "View photo").font(NinaTheme.label)
                        }
                        .foregroundColor(NinaTheme.paper).padding(10)
                        .background(NinaTheme.ink).clipShape(RoundedRectangle(cornerRadius: 12)).padding(12)
                    }
            }.buttonStyle(NinaPress()).accessibilityLabel("Open " + item.title)
            ScrollView(.horizontal, showsIndicators: false) {
                let liked = library.me?.liked.contains(item.id) == true
                let saved = library.me?.saved.contains(item.id) == true
                HStack(spacing: 5) {
                    NinaButton("\(library.visibleLikes(on: item.id))", icon: liked ? .liked : .like, kind: .text) {
                        flow.run { try library.toggleLike(item.id) }
                    }.accessibilityLabel((liked ? "Unlike " : "Like ") + item.title)
                    NinaButton("Comment", icon: .comment, kind: .text) { flow.open(.line(item.id)) }
                    NinaButton(saved ? "Saved" : "Save", icon: saved ? .saved : .save, kind: .text) {
                        flow.run { try library.toggleSave(item.id) }
                    }
                }.padding(8)
            }
        }
        .background(NinaTheme.paper).clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
