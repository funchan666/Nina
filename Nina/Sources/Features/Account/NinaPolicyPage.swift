import SwiftUI
import WebKit

enum NinaPolicy: String, CaseIterable, Identifiable {
    case website, terms, privacy, rules
    var id: Self { self }

    var title: String {
        switch self {
        case .website: return "Official website"
        case .terms: return "Terms of Use"
        case .privacy: return "Privacy Policy"
        case .rules: return "Crew Rules"
        }
    }

    @MainActor var externalURL: URL? {
        switch self {
        case .website: return NinaConfiguration.website
        case .terms: return NinaConfiguration.terms
        case .privacy: return NinaConfiguration.privacy
        case .rules: return nil
        }
    }

    var bundledURL: URL? {
        self == .website ? nil : Bundle.main.url(forResource: rawValue, withExtension: "html")
    }
}

struct NinaPolicyPage: View {
    let policy: NinaPolicy
    let dismiss: () -> Void
    @State private var retry = 0
    @State private var failed = false
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            NinaActionBand(height: 60) {
                HStack(spacing: 10) {
                    NinaIconButton(title: "Close page", icon: .close, bg: NinaTheme.paper, action: dismiss)
                    Text(policy.title).font(NinaTheme.card).accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                }
            }
            if failed {
                VStack(alignment: .leading, spacing: 12) {
                    NinaNotice(text: "Couldn't open \(policy.title).", error: true)
                    NinaButton("Try again", icon: .load) {
                        failed = false
                        loading = true
                        retry += 1
                    }
                }.padding(16)
            }
            if loading && !failed { NinaNotice(text: "Opening \(policy.title)…") }
            NinaPolicyWeb(policy: policy, retry: retry) { status in
                loading = false
                failed = !status
            }
        }
        .foregroundColor(NinaTheme.ink)
        .background(NinaTheme.paper.ignoresSafeArea(.container))
    }
}

private struct NinaPolicyWeb: UIViewRepresentable {
    let policy: NinaPolicy
    let retry: Int
    let loaded: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(loaded: loaded) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = UIColor(NinaTheme.paper)
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        let coordinator = context.coordinator
        guard retry != coordinator.lastRetry else { return }
        coordinator.lastRetry = retry
        coordinator.navigation = nil
        view.stopLoading()
        coordinator.bundled = policy.bundledURL
        coordinator.online = policy.externalURL != nil
        if let url = policy.externalURL {
            coordinator.navigation = view.load(URLRequest(url: url, timeoutInterval: 20))
            if coordinator.navigation == nil { coordinator.loadBundled(view) }
        } else {
            coordinator.loadBundled(view)
        }
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.navigation = nil
        view.stopLoading()
        view.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastRetry = -1
        var navigation: WKNavigation?
        var bundled: URL?
        var online = false
        let loaded: (Bool) -> Void

        init(loaded: @escaping (Bool) -> Void) { self.loaded = loaded }

        func loadBundled(_ view: WKWebView) {
            online = false
            navigation = nil
            if let bundled { navigation = view.loadFileURL(bundled, allowingReadAccessTo: bundled) }
            if navigation == nil { DispatchQueue.main.async { self.loaded(false) } }
        }

        func webView(_ view: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { decisionHandler(.cancel); return }
            let allowed = url.scheme == "https" || (!online && url.isFileURL && url.standardizedFileURL == bundled?.standardizedFileURL)
            guard allowed else { decisionHandler(.cancel); return }
            if action.targetFrame == nil {
                view.load(URLRequest(url: url))
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ view: WKWebView, decidePolicyFor response: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if online, navigation != nil, response.isForMainFrame,
               let http = response.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                navigation = nil
                decisionHandler(.cancel)
                loadBundled(view)
            } else { decisionHandler(.allow) }
        }

        func webView(_ view: WKWebView, didFinish completed: WKNavigation!) {
            guard let completed, completed === navigation else { return }
            navigation = nil
            loaded(true)
        }

        func webView(_ view: WKWebView, didFail failed: WKNavigation!, withError error: Error) { fail(view, failed) }
        func webView(_ view: WKWebView, didFailProvisionalNavigation failed: WKNavigation!, withError error: Error) { fail(view, failed) }

        private func fail(_ view: WKWebView, _ failed: WKNavigation?) {
            guard let failed, failed === navigation else { return }
            if online { loadBundled(view) }
            else { navigation = nil; loaded(false) }
        }
    }
}
