import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

struct NinaIssue: LocalizedError {
    let text: String
    init(_ text: String) { self.text = text }
    var errorDescription: String? { text }
}

enum PlatformConfiguration {
    static func value(_ name: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: name) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func https(_ name: String) -> URL? {
        guard let parsed = URLComponents(string: value(name)), parsed.scheme == "https",
              let host = parsed.host, !host.isEmpty, parsed.user == nil, parsed.password == nil,
              parsed.query == nil, parsed.fragment == nil else { return nil }
        return parsed.url
    }

    static var purchasesEnabled: Bool { value("NinaPurchasesEnabled") == "YES" }
}

enum PlatformJournal {
    private static let currentName = "journal-rn-v2.json"
    private static let previousName = "journal-v1.json"

    @MainActor
    static func open(mediaDirectory: URL?) throws -> [String: Any] {
        let folder = try NinaFiles.root()
        let current = folder.appendingPathComponent(currentName)
        let previous = folder.appendingPathComponent(previousName)
        let currentExists = FileManager.default.fileExists(atPath: current.path)
        let previousExists = FileManager.default.fileExists(atPath: previous.path)
        let legacy = !currentExists && previousExists
        let json: Any
        if currentExists || legacy {
            json = try String(contentsOf: legacy ? previous : current, encoding: .utf8)
        } else {
            json = NSNull()
        }
        let config: [String: Any] = [
            "media": mediaDirectory?.absoluteString ?? "",
            "fileBase": folder.appendingPathComponent("Media", isDirectory: true).absoluteString,
            "supportEmail": PlatformConfiguration.value("NinaSupportEmail"),
            "purchasesEnabled": PlatformConfiguration.purchasesEnabled
        ]
        let activeID: Any
        if let session = try SessionVault.read() {
            activeID = session.uuidString
        } else {
            activeID = NSNull()
        }
        return [
            "json": json, "legacy": legacy, "legacyNeedsCleanup": previousExists && currentExists,
            "activeID": activeID, "config": config
        ]
    }

    static func write(_ text: String, removeLegacy: Bool) throws {
        let folder = try NinaFiles.root()
        let file = folder.appendingPathComponent(currentName)
        let bytes = Data(text.utf8)
        guard let state = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let version = state["version"] as? Int, version == 2 || version == 3 else {
            throw NinaIssue("This journal could not be saved.")
        }
        do {
            try bytes.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            throw NinaIssue("Changes couldn't be saved. Check available storage and try again.")
        }
        if removeLegacy { try cleanLegacy() }
    }

    static func cleanLegacy() throws {
        let folder = try NinaFiles.root()
        let current = folder.appendingPathComponent(currentName)
        let previous = folder.appendingPathComponent(previousName)
        guard FileManager.default.fileExists(atPath: current.path), FileManager.default.fileExists(atPath: previous.path) else {
            return
        }
        try FileManager.default.removeItem(at: previous)
    }

    static func identity(_ source: String, name: String? = nil) -> [String: Any] {
        let key = SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
        var result = ["key": key, "id": UUID().uuidString]
        if let name { result["name"] = name }
        return result
    }
}

@MainActor
final class NinaAppleAuthorization: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var current: ASAuthorizationController?
    private var anchor: UIWindow?
    private var completion: CheckedContinuation<[String: Any], Error>?

    func request() async throws -> [String: Any] {
        guard completion == nil, let window = NinaScene.window else {
            throw NinaIssue("Apple sign-in is unavailable right now.")
        }
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName]
        return try await withCheckedThrowingContinuation { continuation in
            completion = continuation
            anchor = window
            let controller = ASAuthorizationController(authorizationRequests: [request])
            current = controller
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchor ?? UIWindow()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential, !credential.user.isEmpty else {
            settle(.failure(NinaIssue("Apple couldn't return your profile.")))
            return
        }
        let name = credential.fullName.map { PersonNameComponentsFormatter().string(from: $0) }
        settle(.success(PlatformJournal.identity("apple:" + credential.user, name: name)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        settle(.failure(NinaIssue(cancelled ? "Apple sign-in canceled." : "Apple sign-in couldn't complete. Try again.")))
    }

    private func settle(_ outcome: Result<[String: Any], Error>) {
        let pending = completion
        completion = nil
        current = nil
        anchor = nil
        pending?.resume(with: outcome)
    }
}
