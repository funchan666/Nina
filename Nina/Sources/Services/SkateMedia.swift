import AVFoundation
import ImageIO
import UIKit

enum NinaFiles {
    static func root() throws -> URL {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        var folder = support.appendingPathComponent("Nina", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        var protection = URLResourceValues()
        protection.isExcludedFromBackup = true
        try folder.setResourceValues(protection)
        return folder
    }

    private static func userFolder(_ owner: UUID) throws -> URL {
        try root().appendingPathComponent("Media", isDirectory: true).appendingPathComponent(owner.uuidString, isDirectory: true)
    }

    static func mediaURL(_ name: String, owner: UUID) -> URL? {
        guard name.range(of: #"^[A-Fa-f0-9-]{36}\.[a-z0-9]{1,8}$"#, options: .regularExpression) != nil else { return nil }
        return try? userFolder(owner).appendingPathComponent(name)
    }

    static func removeAccount(_ owner: UUID) throws {
        let folder = try userFolder(owner)
        if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) }
    }

    static func remove(_ attachment: SkateAttachment, owner: UUID) {
        for path in [attachment.file, attachment.posterFile].compactMap({ $0 }) {
            guard let url = mediaURL(path, owner: owner) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func importMedia(_ selection: SkateSelection, owner: UUID, forAvatar: Bool = false) async throws -> SkateAttachment {
        let folder = try userFolder(owner)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let ext = selection.url.pathExtension.lowercased()
        let type = selection.type
        let name = UUID().uuidString
        let file = name + (type == .photo ? ".jpg" : "." + (ext == "mp4" ? "mp4" : "mov"))
        let location = folder.appendingPathComponent(file)
        let poster = type == .video ? UUID().uuidString + ".jpg" : nil
        let attachment = SkateAttachment(type: type, file: file, posterFile: poster)
        do {
            if let poster {
                try FileManager.default.copyItem(at: selection.url, to: location)
                let asset = AVURLAsset(url: location)
                guard try await asset.load(.isPlayable) else { throw NinaIssue("This film can't be played.") }
                let first = try await firstFrame(of: asset)
                guard let jpeg = UIImage(cgImage: first).jpegData(compressionQuality: 0.84) else {
                    throw NinaIssue("Couldn't make a cover from this film.")
                }
                try jpeg.write(to: folder.appendingPathComponent(poster), options: .atomic)
            } else {
                let pixels = forAvatar ? 640 : 1600
                guard let image = SkateImages.thumbnail(url: selection.url, pixels: pixels),
                      let jpeg = image.jpegData(compressionQuality: 0.86) else {
                    throw NinaIssue("This photo couldn't be opened.")
                }
                try jpeg.write(to: location, options: .atomic)
            }
            try Task.checkCancellation()
            return attachment
        } catch {
            remove(attachment, owner: owner)
            throw error
        }
    }

    private static func firstFrame(of asset: AVURLAsset) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 840, height: 840)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 20)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: .zero)]) { _, image, _, status, error in
                    if let image, status == .succeeded {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: error ?? NinaIssue("Couldn't read the first frame."))
                    }
                }
            }
        } onCancel: {
            generator.cancelAllCGImageGeneration()
        }
    }
}

final class SkateSelection {
    let url: URL
    let type: LineFormat

    init(copying source: URL, type: LineFormat) throws {
        let suffix = source.pathExtension.isEmpty ? (type == .video ? "mov" : "jpg") : source.pathExtension
        url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(suffix)
        self.type = type
        try FileManager.default.copyItem(at: source, to: url)
    }

    init(photo: UIImage) throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
        type = .photo
        guard let data = photo.jpegData(compressionQuality: 0.9) else { throw NinaIssue("Couldn't save this photo.") }
        try data.write(to: url, options: .atomic)
    }

    deinit { try? FileManager.default.removeItem(at: url) }
}

enum SkateImages {
    static func thumbnail(url: URL, pixels: Int) -> UIImage? {
        CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { thumbnail($0, pixels: pixels) }
    }

    static func thumbnail(_ source: CGImageSource, pixels: Int) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: pixels
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { UIImage(cgImage: $0) }
    }
}

@MainActor
final class LineImageStore {
    static let shared = LineImageStore()
    private let memory = NSCache<NSString, UIImage>()
    private let session: URLSession

    private init() {
        memory.totalCostLimit = 30 * 1024 * 1024
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 18
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024, diskCapacity: 48 * 1024 * 1024, diskPath: "NinaLines")
        session = URLSession(configuration: configuration)
    }

    func image(at url: URL, pixels: Int, reload: Bool) async throws -> UIImage {
        let key = (url.absoluteString + "#\(pixels)") as NSString
        if !reload, !url.isFileURL, let image = memory.object(forKey: key) { return image }
        let image: UIImage?
        if url.isFileURL {
            image = await Task.detached(priority: .utility) { SkateImages.thumbnail(url: url, pixels: pixels) }.value
        } else {
            var request = URLRequest(url: url)
            if reload { request.cachePolicy = .reloadIgnoringLocalCacheData }
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
                  http.mimeType?.hasPrefix("image/") == true else {
                throw NinaIssue("This image is unavailable.")
            }
            try Task.checkCancellation()
            image = await Task.detached(priority: .utility) {
                CGImageSourceCreateWithData(data as CFData, nil).flatMap { SkateImages.thumbnail($0, pixels: pixels) }
            }.value
        }
        try Task.checkCancellation()
        guard let image else { throw NinaIssue("This image couldn't be opened.") }
        if !url.isFileURL {
            let cost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
            memory.setObject(image, forKey: key, cost: cost)
        }
        return image
    }
}
