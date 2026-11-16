import AVFoundation
import PhotosUI
import UIKit
import UniformTypeIdentifiers

enum SkatePickerSource: String {
    case photos, picture, movie

    @MainActor
    func checkAccess() async throws {
        guard self != .photos else { return }
        let mode: UIImagePickerController.CameraCaptureMode = self == .movie ? .video : .photo
        let supported = UIImagePickerController.availableCaptureModes(for: .rear)?.contains { $0.intValue == mode.rawValue } == true ||
            UIImagePickerController.availableCaptureModes(for: .front)?.contains { $0.intValue == mode.rawValue } == true
        guard UIImagePickerController.isSourceTypeAvailable(.camera), supported else {
            throw NinaIssue("This camera mode isn't available.")
        }
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            throw NinaIssue("Allow camera access in Settings to capture skating media.")
        }
        if self == .movie, !(await AVCaptureDevice.requestAccess(for: .audio)) {
            throw NinaIssue("Allow microphone access in Settings to record a clip with sound.")
        }
    }
}

@MainActor
final class NinaPicker: NSObject, PHPickerViewControllerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    private var completion: CheckedContinuation<SkateSelection?, Error>?
    private var busy = false

    func pick(source: SkatePickerSource, owner: UUID, avatar: Bool) async throws -> SkateAttachment? {
        guard !busy else { throw NinaIssue("Finish choosing the current attachment first.") }
        guard !avatar || source != .movie else { throw NinaIssue("Choose a photo for your profile.") }
        busy = true
        defer { busy = false }
        try await source.checkAccess()
        guard let host = NinaScene.controller else { throw NinaIssue("Couldn't open media capture.") }

        let selected: SkateSelection? = try await withCheckedThrowingContinuation { continuation in
            completion = continuation
            if source == .photos {
                var configuration = PHPickerConfiguration(photoLibrary: .shared())
                configuration.selectionLimit = 1
                configuration.filter = avatar ? .images : .any(of: [.images, .videos])
                configuration.preferredAssetRepresentationMode = .compatible
                let picker = PHPickerViewController(configuration: configuration)
                picker.delegate = self
                picker.modalPresentationStyle = .fullScreen
                host.present(picker, animated: true)
            } else {
                let camera = UIImagePickerController()
                camera.sourceType = .camera
                let mode: UIImagePickerController.CameraCaptureMode = source == .movie ? .video : .photo
                if UIImagePickerController.availableCaptureModes(for: .rear)?.contains(where: { $0.intValue == mode.rawValue }) != true {
                    camera.cameraDevice = .front
                }
                camera.mediaTypes = [source == .movie ? UTType.movie.identifier : UTType.image.identifier]
                camera.cameraCaptureMode = mode
                camera.videoQuality = .typeHigh
                camera.delegate = self
                camera.modalPresentationStyle = .fullScreen
                host.present(camera, animated: true)
            }
        }
        guard let selected else { return nil }
        return try await NinaFiles.importMedia(selected, owner: owner, forAvatar: avatar)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let provider = results.first?.itemProvider else {
            close(picker, result: .success(nil))
            return
        }
        let video = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
        let type = video ? UTType.movie : UTType.image
        provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
            let result = Result<SkateSelection?, Error> {
                guard let url else { throw error ?? NinaIssue("This file couldn't be opened.") }
                return try SkateSelection(copying: url, type: video ? .video : .photo)
            }
            DispatchQueue.main.async { self.close(picker, result: result) }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        close(picker, result: .success(nil))
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        close(picker, result: Result {
            if let video = info[.mediaURL] as? URL { return try SkateSelection(copying: video, type: .video) }
            if let photo = info[.originalImage] as? UIImage { return try SkateSelection(photo: photo) }
            throw NinaIssue("The camera didn't return any media.")
        })
    }

    private func close(_ picker: UIViewController, result: Result<SkateSelection?, Error>) {
        guard let pending = completion else { return }
        completion = nil
        picker.dismiss(animated: true) { pending.resume(with: result) }
    }
}
