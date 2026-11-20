import Foundation

@MainActor
enum NinaConfiguration {
    static let website = secureURL("NinaWebsiteURL")
    static let terms = secureURL("NinaTermsURL")
    static let privacy = secureURL("NinaPrivacyURL")
    private(set) static var media: URL?
    static let purchasesEnabled = setting("NinaPurchasesEnabled") == "YES"
    static let supportEmail = setting("NinaSupportEmail")

    static let lines: [LineMedia] = {
        guard let file = Bundle.main.url(forResource: "LinesCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: file) else { return [] }
        return (try? JSONDecoder().decode([LineMedia].self, from: data)) ?? []
    }()

    static func line(_ id: String) -> LineMedia? { lines.first { $0.id == id } }

    static func prepareMedia() async throws {
        guard media == nil else { return }
        let filenames = Set(lines.flatMap { [$0.path] + [$0.poster].compactMap { $0 } })
        guard !filenames.isEmpty, filenames.allSatisfy(validFilename) else {
            throw NinaIssue("The bundled skate collection is incomplete.")
        }
        let folder = try await OfflineArchive.shared.mediaDirectory(filenames: filenames)
        media = folder
    }

    static func setting(_ name: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: name) as? String ?? "").cleaned
    }

    private static func secureURL(_ name: String) -> URL? {
        guard let value = URLComponents(string: setting(name)),
              value.scheme == "https", let host = value.host, !host.isEmpty,
              value.user == nil, value.password == nil, value.query == nil, value.fragment == nil else { return nil }
        return value.url
    }

    static func objectURL(_ path: String) -> URL? {
        guard let media else { return nil }
        guard validFilename(path) else { return nil }
        return media.appendingPathComponent(path)
    }

    private static func validFilename(_ path: String) -> Bool {
        path.range(of: #"^[a-z0-9][a-z0-9.-]*$"#, options: .regularExpression) != nil
    }
}
