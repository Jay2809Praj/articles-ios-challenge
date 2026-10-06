import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard
            let windowScene = scene as? UIWindowScene,
            let appDelegate = UIApplication.shared.delegate as? AppDelegate,
            let router = appDelegate.container.resolve(AppRouter.self)
        else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        window.tintColor = AppColor.accent
        window.rootViewController = router.makeRootViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}
