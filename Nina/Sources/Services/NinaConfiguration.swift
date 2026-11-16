import Foundation

enum NinaConfiguration {
    static let terms = secureURL("NinaTermsURL")
    static let privacy = secureURL("NinaPrivacyURL")
    static let media = secureURL("NinaMediaPublicBaseURL")
    static let purchasesEnabled = setting("NinaPurchasesEnabled") == "YES"
    static let supportEmail = setting("NinaSupportEmail")

    static let lines: [LineMedia] = {
        guard let file = Bundle.main.url(forResource: "LinesCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: file) else { return [] }
        return (try? JSONDecoder().decode([LineMedia].self, from: data)) ?? []
    }()

    static func line(_ id: String) -> LineMedia? { lines.first { $0.id == id } }

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
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.allSatisfy({ $0.range(of: #"^[a-z0-9][a-z0-9.-]*$"#, options: .regularExpression) != nil }) else { return nil }
        return parts.reduce(media) { $0.appendingPathComponent(String($1)) }
    }
}
