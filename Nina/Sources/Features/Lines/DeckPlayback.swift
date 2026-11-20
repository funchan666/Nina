import AVFoundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class DeckPlayback: ObservableObject {
    @Published private(set) var currentID: String?
    @Published private(set) var engaged = false
    @Published private(set) var playing = false
    @Published private(set) var muted = false
    @Published private(set) var time = 0.0
    @Published private(set) var duration = 0.0
    @Published private(set) var loading = false
    @Published private(set) var failed = false

    let player = AVPlayer()
    private var observer: Any?
    private var itemStatus: NSKeyValueObservation?
    private var timeStatus: NSKeyValueObservation?
    private var notifications: [NSObjectProtocol] = []

    init() {
        player.actionAtItemEnd = .pause
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 4), queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let current = self.player.currentTime().seconds
                self.time = current.isFinite ? max(0, current) : 0
                let duration = self.player.currentItem?.duration.seconds ?? 0
                self.duration = duration.isFinite ? max(0, duration) : 0
            }
        }
        timeStatus = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.loading = self.engaged && self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }
    }

    deinit {
        player.pause()
        if let observer { player.removeTimeObserver(observer) }
        for note in notifications { NotificationCenter.default.removeObserver(note) }
    }

    func toggle(id: String, url: URL) {
        if currentID == id, playing {
            pause()
            return
        }
        if currentID != id || failed {
            pause()
            let item = AVPlayerItem(url: url)
            currentID = id
            time = 0
            duration = 0
            failed = false
            player.replaceCurrentItem(with: item)
            watch(item)
        }
        if duration > 0, time >= duration - 0.2 { seek(to: 0) }
        engaged = true
        playing = true
        loading = player.currentItem?.status != .readyToPlay
        player.play()
    }

    func seek(to second: Double) {
        guard duration > 0, second.isFinite else { return }
        let target = min(duration, max(0, second))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        time = target
    }

    func toggleMute() {
        muted.toggle()
        player.isMuted = muted
    }

    func pause() {
        player.pause()
        playing = false
        loading = false
    }

    func releaseMedia() {
        pause()
        itemStatus = nil
        for note in notifications { NotificationCenter.default.removeObserver(note) }
        notifications.removeAll()
        player.replaceCurrentItem(with: nil)
        currentID = nil
        engaged = false
        failed = false
        time = 0
        duration = 0
    }

    private func watch(_ item: AVPlayerItem) {
        for note in notifications { NotificationCenter.default.removeObserver(note) }
        itemStatus = item.observe(\.status, options: [.new, .initial]) { [weak self, weak item] _, _ in
            Task { @MainActor in
                guard let self, let item, self.player.currentItem === item else { return }
                if item.status == .failed {
                    self.failed = true
                    self.pause()
                } else if item.status == .readyToPlay {
                    self.loading = self.playing && self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                }
            }
        }
        notifications = [
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self, weak item] _ in
                Task { @MainActor in
                    guard let self, let item, self.player.currentItem === item else { return }
                    self.pause()
                }
            },
            NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self, weak item] _ in
                Task { @MainActor in
                    guard let self, let item, self.player.currentItem === item else { return }
                    self.failed = true
                    self.pause()
                }
            }
        ]
    }
}

struct SkatePlayerLayer: UIViewRepresentable {
    let player: AVPlayer

    final class Surface: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var videoLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> Surface {
        let view = Surface()
        view.backgroundColor = .black
        view.videoLayer.videoGravity = .resizeAspect
        view.videoLayer.player = player
        return view
    }

    func updateUIView(_ view: Surface, context: Context) { view.videoLayer.player = player }
    static func dismantleUIView(_ view: Surface, coordinator: Void) { view.videoLayer.player = nil }
}
