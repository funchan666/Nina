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

    func mediaDirectory() throws -> URL {
        try package().installed.appendingPathComponent("media", isDirectory: true)
    }

    private func package() throws -> Package {
        if let currentPackage { return currentPackage }
        guard let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String,
              let source = Bundle.main.url(forResource: appName, withExtension: "zip"),
              let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= limit else {
            throw NinaIssue("The bundled community is unavailable.")
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

    func entryURL() throws -> URL {
        let bundle = try package()
        let manager = FileManager.default
        let installed = bundle.installed
        let index = installed.appendingPathComponent("index.html")
        if manager.fileExists(atPath: index.path) { return index }

        let archive = try Archive(url: bundle.source, accessMode: .read)
        var archiveRoot = installed.deletingLastPathComponent()
        try manager.createDirectory(at: archiveRoot, withIntermediateDirectories: true)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try archiveRoot.setResourceValues(resourceValues)
        let stage = archiveRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: stage, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: stage) }

        var required = Set(["index.html", "community.css", "community/community.js"])
        var remaining = UInt64(limit)
        var paths = Set<String>()
        for item in archive {
            let parts = item.path.split(separator: "/", omittingEmptySubsequences: false)
            guard item.type == .file, parts.count <= 4,
                  parts.allSatisfy({ $0.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) != nil }),
                  paths.count < 512, paths.insert(item.path.lowercased()).inserted,
                  item.uncompressedSize <= remaining,
                  item.uncompressedSize <= 1_048_576 || item.uncompressedSize / max(item.compressedSize, 1) <= 200 else {
                throw NinaIssue("The bundled community has an invalid file.")
            }
            remaining -= item.uncompressedSize
            let target = stage.appendingPathComponent(item.path)
            try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard try archive.extract(item, to: target) == item.checksum else {
                throw NinaIssue("The bundled community could not be opened.")
            }
            required.remove(item.path)
        }
        guard required.isEmpty else { throw NinaIssue("The bundled community is incomplete.") }
        if manager.fileExists(atPath: installed.path) { try manager.removeItem(at: installed) }
        try manager.moveItem(at: stage, to: installed)
        return index
    }
}
