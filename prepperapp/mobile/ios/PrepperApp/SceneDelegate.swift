import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        
        // Create main search view controller
        let searchVC = SearchViewController()
        let navigationController = UINavigationController(rootViewController: searchVC)
        
        // Pure black window background
        window?.backgroundColor = .black
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
        // Force dark mode
        window?.overrideUserInterfaceStyle = .dark
        
        // Set brightness to 20% for battery optimization
        UIScreen.main.brightness = 0.2
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Restore 20% brightness when app becomes active
        UIScreen.main.brightness = 0.2
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}