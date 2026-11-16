import SwiftUI
import UIKit

struct SkateStill: View {
    let url: URL?
    var label: String
    var fill = true
    var retryable = false
    var pixels = 1100
    var revision = 0

    @Environment(\.ninaRouteVisible) private var active
    @State private var image: UIImage?
    @State private var shownURL: URL?
    @State private var failed = false
    @State private var reload = 0
    @State private var appliedRevision: Int?
    @State private var appliedReload = 0

    private struct Request: Equatable {
        let url: URL?
        let active: Bool
        let revision: Int
        let reload: Int
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                NinaTheme.sage
                if let image, shownURL == url {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: fill ? .fill : .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .accessibilityLabel(Text(label))
                } else if failed || url == nil {
                    VStack(spacing: 5) {
                        InkGlyph(ink: .ramp, size: 34)
                        Text("Image unavailable").font(NinaTheme.caption)
                        if retryable, url != nil {
                            NinaButton("Retry", icon: .load, kind: .paper) { reload += 1 }
                        }
                    }
                } else {
                    InkGlyph(ink: .load, size: 30)
                        .accessibilityHidden(false)
                        .accessibilityLabel("Loading image")
                }
            }
        }
        .task(id: Request(url: url, active: active, revision: revision, reload: reload)) {
            guard active, let url else { return }
            let changed = shownURL != url || appliedRevision != revision || appliedReload != reload
            guard changed || image == nil || failed else { return }
            let refresh = (shownURL == url && appliedRevision != revision) || appliedReload != reload
            failed = false
            do {
                let fetched = try await LineImageStore.shared.image(at: url, pixels: pixels, reload: refresh)
                try Task.checkCancellation()
                image = fetched
                shownURL = url
                appliedRevision = revision
                appliedReload = reload
            } catch is CancellationError {
                return
            } catch {
                if !Task.isCancelled { failed = true }
            }
        }
    }
}

struct SkateFilm: View {
    let id: String
    let title: String
    let url: URL?
    let poster: URL?
    let height: CGFloat
    var expand: (() -> Void)?
    var report: (() -> Void)?

    @EnvironmentObject private var playback: DeckPlayback
    @Environment(\.ninaRouteVisible) private var visible

    private var selected: Bool { visible && playback.currentID == id }
    private var running: Bool { selected && playback.playing }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if selected && playback.engaged && !playback.failed {
                    SkatePlayerLayer(player: playback.player)
                        .accessibilityLabel(Text(title))
                } else {
                    SkateStill(url: poster, label: title, fill: false)
                }
                if running && playback.loading {
                    Text("Buffering film…")
                        .font(NinaTheme.label)
                        .padding(12)
                        .foregroundColor(NinaTheme.paper)
                        .background(NinaTheme.ink)
                } else if !running, let url {
                    if selected && playback.failed {
                        NinaButton("Retry film", icon: .load) { playback.toggle(id: id, url: url) }
                    } else {
                        NinaIconButton(title: "Play \(title)", icon: .play, bg: NinaTheme.grip) {
                            playback.toggle(id: id, url: url)
                        }
                    }
                }
            }
            .frame(height: height)
            .clipped()

            HStack(spacing: 2) {
                if let url {
                    NinaIconButton(title: running ? "Pause" : "Play", icon: running ? .pause : .play, fg: NinaTheme.paper) {
                        playback.toggle(id: id, url: url)
                    }
                }
                if selected, playback.duration > 0 {
                    SkateFilmPosition(playback: playback)
                } else {
                    Text(url == nil ? "Film unavailable" : "Film")
                        .font(NinaTheme.caption)
                        .foregroundColor(NinaTheme.paper)
                        .padding(.leading, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if url != nil {
                    NinaIconButton(title: playback.muted ? "Unmute" : "Mute",
                                   icon: playback.muted ? .muted : .speaker, fg: NinaTheme.paper) {
                        playback.toggleMute()
                    }
                }
                if let expand {
                    NinaIconButton(title: "Full screen", icon: .expand, fg: NinaTheme.paper, action: expand)
                }
                if let report {
                    NinaIconButton(title: "Report film", icon: .flag, fg: NinaTheme.paper, action: report)
                }
            }
            .padding(.horizontal, 2)
            .background(NinaTheme.ink)
        }
        .onDisappear {
            if playback.currentID == id { playback.pause() }
        }
    }
}

private struct SkateFilmPosition: View {
    @ObservedObject var playback: DeckPlayback

    var body: some View {
        GeometryReader { geometry in
            let travel = max(1, geometry.size.width - 18)
            let progress = max(0, min(1, playback.time / playback.duration))
            ZStack(alignment: .leading) {
                NinaTheme.paper.opacity(0.4).frame(height: 3)
                NinaTheme.grip.frame(width: travel * progress + 9, height: 3)
                InkGlyph(ink: .thumb, size: 20, color: NinaTheme.grip)
                    .offset(x: travel * progress)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { drag in
                let newValue = max(0, min(1, (drag.location.x - 9) / travel))
                playback.seek(to: newValue * playback.duration)
            })
        }
        .frame(minWidth: 17, minHeight: 44)
        .accessibilityElement()
        .accessibilityLabel("Film position")
        .accessibilityValue(Text("\(timeText(playback.time)) of \(timeText(playback.duration))"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: playback.seek(to: playback.time + 5)
            case .decrement: playback.seek(to: playback.time - 5)
            @unknown default: break
            }
        }
    }
}

func timeText(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let count = Int(min(seconds, 86_400))
    return String(format: "%d:%02d", count / 60, count % 60)
}

struct LineMediaStage<Content: View>: View {
    let title: String
    let close: () -> Void
    @ViewBuilder var content: (GeometryProxy) -> Content

    var body: some View {
        VStack(spacing: 0) {
            NinaActionBand(height: 54) {
                HStack(spacing: 6) {
                    NinaIconButton(title: "Close media", icon: .close, fg: NinaTheme.paper, action: close)
                    Text(title)
                        .font(NinaTheme.label)
                        .lineLimit(2)
                        .foregroundColor(NinaTheme.paper)
                    Spacer(minLength: 0)
                }
            }
            GeometryReader(content: content)
        }
        .background(NinaTheme.ink.ignoresSafeArea(.container))
    }
}
