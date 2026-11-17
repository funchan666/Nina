import AuthenticationServices
import AVFoundation
import Combine
import Foundation
import UIKit

@MainActor
enum NinaMedia {
    static let playback = DeckPlayback()
    static let camera = SkateCallCamera()
    static var device: AVCaptureDevice?
}

@MainActor
@objc(NinaPlatform)
final class NinaPlatform: NSObject {
    private let authorization = NinaAppleAuthorization()
    private let picker = NinaPicker()
    private let purchases = NinaPurchases()
    private var playbackObserver: AnyCancellable?
    private var pendingFilmUpdate = false
    private var callRequest: String?
    private var preparingCall = false

    override init() {
        super.init()
        playbackObserver = NinaMedia.playback.objectWillChange.sink { [weak self] _ in
            self?.scheduleFilmEvent()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(pauseForInactivity),
                                               name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(backgrounded),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appleRevoked),
                                               name: ASAuthorizationAppleIDProvider.credentialRevokedNotification, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc(perform:inputs:completion:)
    func perform(_ operation: String, inputs: NSDictionary, completion: @escaping (Any?, NSError?) -> Void) {
        Task { @MainActor in
            do {
                completion(try await handle(operation, data: inputs as? [String: Any] ?? [:]), nil)
            } catch {
                completion(nil, error as NSError)
            }
        }
    }

    private func handle(_ operation: String, data: [String: Any]) async throws -> Any? {
        switch operation {
        case "bootstrap":
            let mediaDirectory = try? await OfflineArchive.shared.mediaDirectory()
            return try PlatformJournal.open(mediaDirectory: mediaDirectory)
        case "windowLayout":
            return NinaScene.layout
        case "writeArchive":
            try PlatformJournal.write(try string("json", in: data), removeLegacy: data["removeLegacy"] as? Bool ?? false)
        case "cleanLegacy":
            try PlatformJournal.cleanLegacy()
        case "session":
            let value = data["id"] as? String
            let id = value.flatMap(UUID.init(uuidString:))
            if value != nil && id == nil { throw NinaIssue("This profile is unavailable.") }
            try SessionVault.write(id)
        case "identity":
            return PlatformJournal.identity(try string("value", in: data))
        case "registerPassword":
            try await LocalPassword.shared.register(try string("password", in: data), owner: try owner(in: data))
        case "verifyPassword":
            try await LocalPassword.shared.verify(try string("password", in: data), owner: try owner(in: data))
        case "appleSignIn":
            return try await authorization.request()
        case "pick":
            guard let source = SkatePickerSource(rawValue: try string("source", in: data)) else {
                throw NinaIssue("This media source is unavailable.")
            }
            let id = try owner(in: data)
            guard try SessionVault.read() == id else { throw NinaIssue("Open the profile that owns this media.") }
            NinaMedia.playback.pause()
            let attachment = try await picker.pick(source: source, owner: id, avatar: data["avatar"] as? Bool ?? false)
            if try SessionVault.read() != id {
                if let attachment { NinaFiles.remove(attachment, owner: id) }
                throw NinaIssue("Open the profile that owns this media.")
            }
            return attachment?.payload
        case "removeAttachment":
            guard let media = data["attachment"] as? [String: Any] else {
                throw NinaIssue("This attachment is unavailable.")
            }
            NinaFiles.remove(try SkateAttachment(payload: media), owner: try owner(in: data))
        case "removeAccount":
            let id = try owner(in: data)
            try await LocalPassword.shared.remove(id)
            try NinaFiles.removeAccount(id)
        case "playFilm":
            try play(data)
        case "pauseFilm":
            NinaMedia.playback.pause()
        case "releaseFilm":
            NinaMedia.playback.releaseMedia()
        case "muteFilm":
            NinaMedia.playback.toggleMute()
        case "seekFilm":
            let position = data["seconds"] as? Double ?? 0
            NinaMedia.playback.seek(to: position)
        case "beginCall":
            try await beginCall(request: try string("requestID", in: data), video: data["video"] as? Bool ?? false)
        case "stopCall":
            if try string("requestID", in: data) == callRequest { stopCall() }
        case "quote":
            return try await purchases.price(for: try string("productID", in: data))
        case "purchase":
            let id = try owner(in: data)
            guard try SessionVault.read() == id else { throw NinaIssue("Switch back to the profile that opened this offer.") }
            return try await purchases.buy(try string("productID", in: data), owner: id)
        case "recoverPurchases":
            return try await purchases.recover()
        case "startPurchases":
            return try await purchases.start()
        case "finishPurchase":
            await purchases.finish(try string("transactionID", in: data))
        default:
            throw NinaIssue("This iPhone action is unavailable.")
        }
        return nil
    }

    private func string(_ key: String, in inputs: [String: Any]) throws -> String {
        guard let value = inputs[key] as? String, !value.isEmpty else { throw NinaIssue("This action is missing information.") }
        return value
    }

    private func owner(in data: [String: Any]) throws -> UUID {
        guard let value = UUID(uuidString: try string("owner", in: data)) else {
            throw NinaIssue("This profile is unavailable.")
        }
        return value
    }

    private func play(_ data: [String: Any]) throws {
        let path = try string("uri", in: data)
        guard let url = URL(string: path), url.isFileURL else {
            throw NinaIssue("This film is unavailable.")
        }
        NinaMedia.playback.toggle(id: try string("id", in: data), url: url)
    }

    private func scheduleFilmEvent() {
        guard !pendingFilmUpdate else { return }
        pendingFilmUpdate = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pendingFilmUpdate = false
            let player = NinaMedia.playback
            var payload: [String: Any] = [
                "engaged": player.engaged, "playing": player.playing, "muted": player.muted,
                "time": player.time, "duration": player.duration,
                "loading": player.loading, "failed": player.failed
            ]
            if let id = player.currentID { payload["id"] = id }
            NotificationCenter.default.post(name: NSNotification.Name("NinaFilmState"), object: nil, userInfo: payload)
        }
    }

    private func beginCall(request: String, video: Bool) async throws {
        guard !preparingCall, callRequest == nil else { throw NinaIssue("Close the current waiting screen first.") }
        callRequest = request
        preparingCall = true
        defer { preparingCall = false }
        do {
            guard await AVCaptureDevice.requestAccess(for: .audio) else {
                throw NinaIssue("Allow microphone access in Settings to open call waiting.")
            }
            try checkCall(request)
            if video {
                guard await AVCaptureDevice.requestAccess(for: .video) else {
                    throw NinaIssue("Allow camera access in Settings to see your camera.")
                }
                try checkCall(request)
                let device = try await NinaMedia.camera.start()
                try checkCall(request)
                NinaMedia.device = device
            }
        } catch {
            stopCall()
            throw error
        }
    }

    private func checkCall(_ request: String) throws {
        guard callRequest == request, UIApplication.shared.applicationState != .background else {
            throw NinaIssue("Call waiting is no longer available.")
        }
    }

    private func stopCall() {
        callRequest = nil
        NinaMedia.camera.stop()
        NinaMedia.device = nil
    }

    @objc private func pauseForInactivity() { NinaMedia.playback.pause() }

    @objc private func backgrounded() {
        let open = callRequest != nil
        stopCall()
        if open { NotificationCenter.default.post(name: NSNotification.Name("NinaCallStopped"), object: nil) }
    }

    @objc private func appleRevoked() {
        NotificationCenter.default.post(name: NSNotification.Name("NinaAppleRevoked"), object: nil)
    }
}
