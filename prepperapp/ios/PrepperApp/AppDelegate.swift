import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var backgroundSessionCompletionHandler: (() -> Void)?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize Tantivy logging (commented out as we're using ContentManager now)
        // tantivy_init_logging()
        
        // Create window
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // Set up root view controller with tab bar
        let mainTabBarController = MainTabBarController()
        
        // Configure navigation bar for OLED black theme
        configureNavigationBarAppearance()
        
        window?.rootViewController = mainTabBarController
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
    
    // MARK: - Background Downloads
    
    func application(_ application: UIApplication, 
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        // Store the completion handler to be called when downloads finish
        backgroundSessionCompletionHandler = completionHandler
        
        // The ContentDownloadManager will call this handler when all downloads complete
        print("PrepperApp: Handling background download events for session: \(identifier)")
    }
}