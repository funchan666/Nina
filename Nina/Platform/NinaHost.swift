import React
import React_RCTAppDelegate
import ReactAppDependencyProvider
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {}

final class SceneDelegate: RCTDefaultReactNativeFactoryDelegate, UIWindowSceneDelegate {
    var window: UIWindow?
    private var factory: RCTReactNativeFactory?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        dependencyProvider = RCTAppDependencyProvider()
        let factory = RCTReactNativeFactory(delegate: self)
        let window = UIWindow(windowScene: windowScene)
        self.factory = factory
        self.window = window
        NinaScene.window = window
        factory.startReactNative(withModuleName: "Nina", in: window, connectionOptions: connectionOptions)
    }

    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        RCTLinkingManager.scene(scene, openURLContexts: contexts)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        RCTLinkingManager.scene(scene, continue: userActivity)
    }

    override func createRootViewController() -> UIViewController {
        NinaRootController()
    }

    override func bundleURL() -> URL? {
        #if DEBUG
        RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
        #else
        Bundle.main.url(forResource: "main", withExtension: "jsbundle")
        #endif
    }
}

@MainActor
enum NinaScene {
    static weak var window: UIWindow?
    static var layout: [String: Any] = ["margins": ["left": 18, "right": 18], "regions": []]

    static var controller: UIViewController? {
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }

    static func observeLayout(of view: UIView) {
        guard let window = view.window else { return }
        let margins = view.directionalLayoutMargins
        let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
        let leading = rtl ? margins.trailing : margins.leading
        let trailing = rtl ? margins.leading : margins.trailing
        let safe = view.safeAreaInsets
        let regions: [CGRect]
        if #available(iOS 27.1, *) {
            regions = (view.reservedRegions(kind: .division, options: []) + view.reservedRegions(kind: .occlusion, options: []))
                .filter(\.isActive)
                .map { view.convert($0.frame, to: window) }
        } else {
            regions = []
        }
        let next: [String: Any] = [
            "margins": ["left": max(16, leading - safe.left), "right": max(16, trailing - safe.right)],
            "regions": regions.map { ["x": $0.minX, "y": $0.minY, "width": $0.width, "height": $0.height] }
        ]
        guard !(next as NSDictionary).isEqual(layout) else { return }
        layout = next
        NotificationCenter.default.post(name: NSNotification.Name("NinaWindowLayout"), object: nil, userInfo: next)
    }
}

private final class NinaRootController: UIViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        NinaScene.observeLayout(of: view)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        NinaScene.observeLayout(of: view)
    }
}
