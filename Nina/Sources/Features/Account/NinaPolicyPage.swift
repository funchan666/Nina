import SwiftUI
import WebKit

enum NinaPolicy: String, CaseIterable, Identifiable {
    case terms, privacy, rules
    var id: Self { self }

    var title: String {
        switch self {
        case .terms: return "Terms of Use"
        case .privacy: return "Privacy Policy"
        case .rules: return "Crew Rules"
        }
    }

    var externalURL: URL? {
        switch self {
        case .terms: return NinaConfiguration.terms
        case .privacy: return NinaConfiguration.privacy
        case .rules: return nil
        }
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
                    NinaIconButton(title: "Close policy", icon: .close, bg: NinaTheme.paper, action: dismiss)
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
                }
                .padding(16)
            }
            if loading && !failed { NinaNotice(text: "Opening \(policy.title)…") }
            NinaPolicyWeb(policy: policy, retry: retry) { status in
                loading = false
                failed = !status
            }
        }
        .foregroundColor(NinaTheme.ink)
        .background(NinaTheme.paper.ignoresSafeArea())
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
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        let coordinator = context.coordinator
        guard retry != coordinator.lastRetry else { return }
        coordinator.lastRetry = retry
        if let url = policy.externalURL {
            view.load(URLRequest(url: url, timeoutInterval: 20))
        } else if let bundled = Bundle.main.url(forResource: policy.rawValue, withExtension: "html") {
            view.loadFileURL(bundled, allowingReadAccessTo: bundled)
        } else {
            DispatchQueue.main.async { loaded(false) }
        }
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        view.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastRetry = -1
        let loaded: (Bool) -> Void

        init(loaded: @escaping (Bool) -> Void) { self.loaded = loaded }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let scheme = navigationAction.request.url?.scheme
            decisionHandler(scheme == "https" || scheme == "file" ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded(true) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { loaded(false) }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { loaded(false) }
    }
}
