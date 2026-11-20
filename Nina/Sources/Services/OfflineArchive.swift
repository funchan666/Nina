import CryptoKit
import Foundation
import ZIPFoundation

actor OfflineArchive {
    static let shared = OfflineArchive()

    private struct Package {
        let source: URL
        let installed: URL
    }

    private let limit = 64 * 1024 * 1024
    private var currentPackage: Package?

    private func package() throws -> Package {
        if let currentPackage { return currentPackage }
        guard let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String,
              let source = Bundle.main.url(forResource: appName, withExtension: "zip"),
              let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= limit else {
            throw NinaIssue("The bundled skate collection is unavailable.")
        }
        let digest = SHA256.hash(data: try Data(contentsOf: source, options: .mappedIfSafe))
            .map { String(format: "%02x", $0) }.joined()
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let archiveRoot = support.appendingPathComponent("NinaCommunity", isDirectory: true)
        let package = Package(source: source, installed: archiveRoot.appendingPathComponent(digest, isDirectory: true))
        currentPackage = package
        return package
    }

    func mediaDirectory(filenames: Set<String>) throws -> URL {
        guard !filenames.isEmpty, filenames.count <= 512,
              filenames.allSatisfy({ $0.range(of: #"^[a-z0-9][a-z0-9.-]*$"#, options: .regularExpression) != nil }) else {
            throw NinaIssue("The bundled skate catalog is invalid.")
        }
        let bundle = try package()
        let manager = FileManager.default
        let installed = bundle.installed
        let media = installed.appendingPathComponent("media", isDirectory: true)
        let expected = Set(filenames.map { "media/" + $0 })
        if filenames.allSatisfy({ manager.fileExists(atPath: media.appendingPathComponent($0).path) }) {
            removePreviousPackages(keeping: installed)
            return media
        }

        let archive = try Archive(url: bundle.source, accessMode: .read)
        var archiveRoot = installed.deletingLastPathComponent()
        try manager.createDirectory(at: archiveRoot, withIntermediateDirectories: true)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try archiveRoot.setResourceValues(resourceValues)
        let stage = archiveRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: stage, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: stage) }

        var required = expected
        var remaining = UInt64(limit)
        var paths = Set<String>()
        for item in archive {
            let parts = item.path.split(separator: "/", omittingEmptySubsequences: false)
            guard item.type == .file, parts.count == 2, expected.contains(item.path),
                  parts.allSatisfy({ $0.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) != nil }),
                  paths.count < 512, paths.insert(item.path.lowercased()).inserted,
                  item.uncompressedSize <= remaining,
                  item.uncompressedSize <= 1_048_576 || item.uncompressedSize / max(item.compressedSize, 1) <= 200 else {
                throw NinaIssue("The bundled skate collection has an invalid file.")
            }
            remaining -= item.uncompressedSize
            let target = stage.appendingPathComponent(item.path)
            try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard try archive.extract(item, to: target) == item.checksum else {
                throw NinaIssue("The bundled skate collection could not be opened.")
            }
            required.remove(item.path)
        }
        guard required.isEmpty else { throw NinaIssue("The bundled skate collection is incomplete.") }
        if manager.fileExists(atPath: installed.path) { try manager.removeItem(at: installed) }
        try manager.moveItem(at: stage, to: installed)
        removePreviousPackages(keeping: installed)
        return media
    }

    private func removePreviousPackages(keeping installed: URL) {
        let manager = FileManager.default
        guard let previous = try? manager.contentsOfDirectory(at: installed.deletingLastPathComponent(), includingPropertiesForKeys: nil) else { return }
        for file in previous where file.lastPathComponent != installed.lastPathComponent &&
            file.lastPathComponent.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) != nil {
            try? manager.removeItem(at: file)
        }
    }
}
