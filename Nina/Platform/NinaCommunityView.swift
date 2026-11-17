import UIKit
import WebKit

private typealias CommunityReply = @MainActor @Sendable (Any?, String?) -> Void

@objc(NinaCommunityView)
final class NinaCommunityView: UIView, WKNavigationDelegate {
    @objc var onSignal: (([String: Any]) -> Void)?
    @objc var reply: NSDictionary? {
        didSet {
            guard let pending, reply?["id"] as? String == pending.id else { return }
            self.pending = nil
            pending.resolve(reply?["value"], reply?["error"] as? String)
        }
    }

    private let webView: WKWebView
    private var index: URL?
    private var started = false
    private var pending: (id: String, resolve: CommunityReply)?

    override init(frame: CGRect) {
        let handler = CommunityMessages()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.addScriptMessageHandler(handler, contentWorld: .page, name: "nina")
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: frame)
        handler.owner = self
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.keyboardDismissMode = .interactive
        addSubview(webView)
    }

    required init?(coder: NSCoder) { return nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        webView.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !started else { return }
        started = true
        Task { [weak self] in
            do {
                let entry = try await OfflineArchive.shared.entryURL()
                self?.open(entry)
            } catch {
                self?.failed()
            }
        }
    }

    private func open(_ entry: URL) {
        index = entry
        if webView.loadFileURL(entry, allowingReadAccessTo: entry.deletingLastPathComponent()) == nil {
            failed()
        }
    }

    private func isEntry(_ url: URL?) -> Bool {
        guard let index, let url, url.isFileURL else { return false }
        return index.resolvingSymlinksInPath().path == url.resolvingSymlinksInPath().path
    }

    fileprivate func receive(_ message: WKScriptMessage, resolve: @escaping CommunityReply) {
        guard message.frameInfo.isMainFrame, isEntry(message.frameInfo.request.url),
              let body = message.body as? [String: Any], let action = body["action"] as? String,
              let deliver = onSignal, pending == nil else {
            resolve(nil, "This community action is unavailable. Try again.")
            return
        }
        let id = UUID().uuidString
        pending = (id, resolve)
        deliver(["status": "request", "id": id, "action": action, "data": body["data"] ?? [:]])
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        let local = isEntry(action.request.url) && action.targetFrame?.isMainFrame != false
        decisionHandler(local ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onSignal?(["status": "loaded"])
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        failed()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        failed()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        failed()
    }

    private func failed() {
        let previous = pending
        pending = nil
        previous?.resolve(nil, "The community page closed. Open it again.")
        onSignal?(["status": "failed"])
    }
}

private final class CommunityMessages: NSObject, WKScriptMessageHandlerWithReply {
    weak var owner: NinaCommunityView?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping CommunityReply) {
        guard let owner else {
            replyHandler(nil, "The community page closed. Open it again.")
            return
        }
        owner.receive(message, resolve: replyHandler)
    }
}
