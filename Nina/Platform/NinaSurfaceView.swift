import AuthenticationServices
import AVFoundation
import UIKit
import WebKit

@objc(NinaSurfaceView)
final class NinaSurfaceView: UIView, WKNavigationDelegate {
    private enum WebPage: String {
        case website, terms, privacy, rules

        var urlSetting: String? {
            switch self {
            case .website: return "NinaWebsiteURL"
            case .terms: return "NinaTermsURL"
            case .privacy: return "NinaPrivacyURL"
            case .rules: return nil
            }
        }
    }

    @objc var kind = "" {
        didSet { if oldValue != kind { mount() } }
    }
    @objc var enabled = true {
        didSet { apple?.isEnabled = enabled }
    }
    @objc var page: String? {
        didSet { if page != oldValue { loadPage() } }
    }
    @objc var revision: NSNumber? {
        didSet { if revision != oldValue && oldValue != nil { loadPage() } }
    }
    @objc var onSignal: (([String: Any]) -> Void)?

    private var apple: ASAuthorizationAppleIDButton?
    private var film: AVPlayerLayer?
    private var camera: AVCaptureVideoPreviewLayer?
    private var web: WKWebView?
    private var loadingNavigation: WKNavigation?
    private var bundledPage: URL?
    private var loadingOnline = false
    private var rotationCoordinator: NSObject?
    private var rotation: NSKeyValueObservation?

    override func layoutSubviews() {
        super.layoutSubviews()
        apple?.frame = bounds
        web?.frame = bounds
        film?.frame = bounds
        camera?.frame = bounds
        if #unavailable(iOS 17), let connection = camera?.connection, connection.isVideoOrientationSupported {
            switch window?.windowScene?.interfaceOrientation {
            case .landscapeLeft: connection.videoOrientation = .landscapeLeft
            case .landscapeRight: connection.videoOrientation = .landscapeRight
            case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
            default: connection.videoOrientation = .portrait
            }
        }
    }

    private func mount() {
        apple?.removeFromSuperview()
        apple = nil
        film?.player = nil
        film?.removeFromSuperlayer()
        film = nil
        camera?.session = nil
        camera?.removeFromSuperlayer()
        camera = nil
        rotation = nil
        rotationCoordinator = nil
        web?.navigationDelegate = nil
        web?.stopLoading()
        web?.removeFromSuperview()
        web = nil
        loadingNavigation = nil
        bundledPage = nil
        loadingOnline = false

        switch kind {
        case "apple":
            let button = ASAuthorizationAppleIDButton(type: .continue, style: .white)
            button.cornerRadius = 0
            button.isEnabled = enabled
            button.addTarget(self, action: #selector(applePressed), for: .touchUpInside)
            apple = button
            addSubview(button)
        case "film":
            let playerLayer = AVPlayerLayer(player: NinaMedia.playback.player)
            playerLayer.videoGravity = .resizeAspect
            playerLayer.backgroundColor = UIColor.black.cgColor
            layer.addSublayer(playerLayer)
            film = playerLayer
        case "camera":
            let preview = AVCaptureVideoPreviewLayer(session: NinaMedia.camera.session)
            preview.videoGravity = .resizeAspectFill
            preview.backgroundColor = UIColor.black.cgColor
            if let connection = preview.connection, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = true
            }
            layer.addSublayer(preview)
            camera = preview
            if #available(iOS 17, *), let device = NinaMedia.device {
                let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: preview)
                rotationCoordinator = coordinator
                rotation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak preview] _, change in
                    guard let angle = change.newValue else { return }
                    DispatchQueue.main.async {
                        guard let connection = preview?.connection, connection.isVideoRotationAngleSupported(angle) else { return }
                        connection.videoRotationAngle = angle
                    }
                }
            }
        case "web":
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .nonPersistent()
            let document = WKWebView(frame: bounds, configuration: configuration)
            document.isOpaque = false
            document.backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1)
            document.navigationDelegate = self
            document.allowsBackForwardNavigationGestures = true
            document.scrollView.contentInsetAdjustmentBehavior = .never
            web = document
            addSubview(document)
            loadPage()
        default:
            break
        }

        setNeedsLayout()
    }

    @objc private func applePressed() {
        onSignal?(["status": "pressed"])
    }

    private func loadPage() {
        guard let web, let page, let target = WebPage(rawValue: page) else { return }
        loadingNavigation = nil
        web.stopLoading()
        bundledPage = target == .website ? nil : Bundle.main.url(forResource: target.rawValue, withExtension: "html")
        onSignal?(["status": "loading"])
        if let setting = target.urlSetting, let url = PlatformConfiguration.https(setting) {
            loadingOnline = true
            loadingNavigation = web.load(URLRequest(url: url, timeoutInterval: 20))
            if loadingNavigation != nil { return }
        }
        loadBundledPage()
    }

    private func loadBundledPage() {
        loadingOnline = false
        loadingNavigation = nil
        if let web, let url = bundledPage {
            loadingNavigation = web.loadFileURL(url, allowingReadAccessTo: url)
        }
        if loadingNavigation == nil {
            onSignal?(["status": "failed"])
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = action.request.url
        let isBundledPage = !loadingOnline && url?.isFileURL == true && url?.path == bundledPage?.path
        decisionHandler(url?.scheme == "https" || isBundledPage ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard webView === web, response.isForMainFrame, loadingOnline, loadingNavigation != nil,
              let http = response.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else {
            decisionHandler(.allow)
            return
        }
        loadingNavigation = nil
        decisionHandler(.cancel)
        loadBundledPage()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let navigation, navigation === loadingNavigation else { return }
        loadingOnline = false
        loadingNavigation = nil
        onSignal?(["status": "loaded"])
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        failNavigation(navigation)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        failNavigation(navigation)
    }

    private func failNavigation(_ navigation: WKNavigation?) {
        guard let navigation, navigation === loadingNavigation else { return }
        if loadingOnline {
            loadBundledPage()
        } else {
            loadingNavigation = nil
            onSignal?(["status": "failed"])
        }
    }
}
