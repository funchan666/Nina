import AuthenticationServices
import AVFoundation
import UIKit
import WebKit

@objc(NinaSurfaceView)
final class NinaSurfaceView: UIView, WKNavigationDelegate {
    @objc var kind = "" {
        didSet { if oldValue != kind { mount() } }
    }
    @objc var enabled = true {
        didSet { apple?.isEnabled = enabled }
    }
    @objc var policy: String? {
        didSet { if policy != oldValue { loadPolicy() } }
    }
    @objc var revision: NSNumber? {
        didSet { if revision != oldValue && oldValue != nil { loadPolicy() } }
    }
    @objc var onSignal: (([String: Any]) -> Void)?

    private var apple: ASAuthorizationAppleIDButton?
    private var film: AVPlayerLayer?
    private var camera: AVCaptureVideoPreviewLayer?
    private var web: WKWebView?
    private var loadingNavigation: WKNavigation?
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
        case "policy":
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .nonPersistent()
            let document = WKWebView(frame: bounds, configuration: configuration)
            document.isOpaque = false
            document.backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1)
            document.navigationDelegate = self
            web = document
            addSubview(document)
            loadPolicy()
        default:
            break
        }

        setNeedsLayout()
    }

    @objc private func applePressed() {
        onSignal?(["status": "pressed"])
    }

    private func loadPolicy() {
        guard let web, let policy, ["terms", "privacy", "rules"].contains(policy) else { return }
        web.stopLoading()
        onSignal?(["status": "loading"])
        let setting = policy == "terms" ? "NinaTermsURL" : "NinaPrivacyURL"
        if policy != "rules", let url = PlatformConfiguration.https(setting) {
            loadingNavigation = web.load(URLRequest(url: url, timeoutInterval: 20))
        } else if let url = Bundle.main.url(forResource: policy, withExtension: "html") {
            loadingNavigation = web.loadFileURL(url, allowingReadAccessTo: url)
        } else {
            onSignal?(["status": "failed"])
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = action.request.url?.scheme
        decisionHandler(scheme == "https" || scheme == "file" ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if navigation === loadingNavigation { onSignal?(["status": "loaded"]) }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if navigation === loadingNavigation { onSignal?(["status": "failed"]) }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if navigation === loadingNavigation { onSignal?(["status": "failed"]) }
    }
}
