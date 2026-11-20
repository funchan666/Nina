import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

enum SkatePickerSource: String, Identifiable {
    case photos, picture, movie
    var id: Self { self }

    var isCamera: Bool { self != .photos }

    @MainActor
    func checkAccess() async throws {
        guard isCamera else { return }
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

struct SkatePhotoLibrary: UIViewControllerRepresentable {
    let allowsVideo: Bool
    let completion: (Result<SkateSelection, Error>?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = allowsVideo ? .any(of: [.images, .videos]) : .images
        configuration.preferredAssetRepresentationMode = .compatible
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: (Result<SkateSelection, Error>?) -> Void
        init(completion: @escaping (Result<SkateSelection, Error>?) -> Void) { self.completion = completion }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                completion(nil)
                return
            }
            let video = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
            let kind = video ? UTType.movie : UTType.image
            provider.loadFileRepresentation(forTypeIdentifier: kind.identifier) { url, error in
                let result = Result {
                    guard let url else { throw error ?? NinaIssue("This file couldn't be opened.") }
                    return try SkateSelection(copying: url, type: video ? .video : .photo)
                }
                DispatchQueue.main.async { self.completion(result) }
            }
        }
    }
}

struct SkateCamera: UIViewControllerRepresentable {
    let recordsMovie: Bool
    let completion: (Result<SkateSelection, Error>?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        let mode: UIImagePickerController.CameraCaptureMode = recordsMovie ? .video : .photo
        if UIImagePickerController.availableCaptureModes(for: .rear)?.contains(where: { $0.intValue == mode.rawValue }) != true {
            picker.cameraDevice = .front
        }
        picker.mediaTypes = [recordsMovie ? UTType.movie.identifier : UTType.image.identifier]
        picker.cameraCaptureMode = mode
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (Result<SkateSelection, Error>?) -> Void
        init(completion: @escaping (Result<SkateSelection, Error>?) -> Void) { self.completion = completion }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            completion(Result {
                if let video = info[.mediaURL] as? URL { return try SkateSelection(copying: video, type: .video) }
                if let image = info[.originalImage] as? UIImage { return try SkateSelection(photo: image) }
                throw NinaIssue("The camera didn't return any media.")
            })
        }
    }
}

struct SkatePickerButton: View {
    let source: SkatePickerSource
    let title: String
    let icon: NinaInk
    var allowsVideo = false
    let pick: (SkateSelection) -> Void
    let report: (String) -> Void
    @EnvironmentObject private var playback: DeckPlayback
    @State private var open = false
    @State private var checking = false

    var body: some View {
        NinaButton(title, icon: icon, kind: .paper) {
            guard !checking else { return }
            playback.pause()
            checking = true
            Task {
                defer { checking = false }
                do {
                    try await source.checkAccess()
                    open = true
                } catch {
                    report((error as? NinaIssue)?.text ?? "Couldn't open media capture.")
                }
            }
        }
        .disabled(checking)
        .fullScreenCover(isPresented: $open) {
            if source.isCamera {
                SkateCamera(recordsMovie: source == .movie, completion: finish)
                    .ignoresSafeArea()
            } else {
                SkatePhotoLibrary(allowsVideo: allowsVideo, completion: finish)
                    .ignoresSafeArea()
            }
        }
    }

    private func finish(_ result: Result<SkateSelection, Error>?) {
        guard open else { return }
        open = false
        switch result {
        case .success(let item): pick(item)
        case .failure(let error): report((error as? NinaIssue)?.text ?? "Couldn't import the selected media.")
        case nil: break
        }
    }
}
