import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize Tantivy logging
        tantivy_init_logging()
        
        // Create window
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // Set up root view controller
        let searchVC = SearchViewController()
        let navController = UINavigationController(rootViewController: searchVC)
        
        // Configure navigation bar for OLED black theme
        configureNavigationBarAppearance()
        
        window?.rootViewController = navController
        window?.makeKeyAndVisible()
        
        // Set background color to pure black
        window?.backgroundColor = .black
        
        return true
    }
    
    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = .white
        UINavigationBar.appearance().barStyle = .black
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        // Handle memory warning - clear caches if needed
        print("PrepperApp: Memory warning received")
    }
}