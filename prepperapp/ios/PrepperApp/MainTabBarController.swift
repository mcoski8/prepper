import UIKit

class MainTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupAppearance()
        setupViewControllers()
        loadContent()
    }
    
    private func setupAppearance() {
        // Pure black tab bar for OLED
        tabBar.barTintColor = .black
        tabBar.tintColor = .systemRed
        tabBar.unselectedItemTintColor = .systemGray
        
        // Remove tab bar border
        tabBar.shadowImage = UIImage()
        tabBar.backgroundImage = UIImage()
        
        // Make tab bar opaque
        tabBar.isTranslucent = false
        
        // Set navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = .black
        navBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().tintColor = .systemRed
    }
    
    private func setupViewControllers() {
        // Emergency - First tab for immediate access
        let emergencyVC = EmergencyViewController()
        emergencyVC.tabBarItem = UITabBarItem(
            title: "Emergency",
            image: UIImage(systemName: "exclamationmark.triangle.fill"),
            selectedImage: UIImage(systemName: "exclamationmark.triangle.fill")
        )
        let emergencyNav = UINavigationController(rootViewController: emergencyVC)
        
        // Search
        let searchVC = SearchViewController()
        searchVC.tabBarItem = UITabBarItem(
            title: "Search",
            image: UIImage(systemName: "magnifyingglass"),
            selectedImage: UIImage(systemName: "magnifyingglass")
        )
        let searchNav = UINavigationController(rootViewController: searchVC)
        
        // Set initial view controllers
        viewControllers = [emergencyNav, searchNav]
        
        // Default to emergency tab
        selectedIndex = 0
    }
    
    private func loadContent() {
        // Initialize content when app launches
        ContentManager.shared.discoverContent { [weak self] result in
            switch result {
            case .success(let bundle):
                print("Content loaded: \(bundle.manifest.name)")
                self?.updateTabsBasedOnContent(bundle.manifest)
                
            case .failure(let error):
                print("Content loading failed: \(error)")
                // Continue with fallback content
            }
        }
    }
    
    private func updateTabsBasedOnContent(_ manifest: ContentManifest) {
        guard var controllers = viewControllers else { return }
        
        // Add browse tab if we have categories
        if !manifest.content.categories.isEmpty && controllers.count == 2 {
            let browseVC = BrowseViewController()
            browseVC.tabBarItem = UITabBarItem(
                title: "Browse",
                image: UIImage(systemName: "folder"),
                selectedImage: UIImage(systemName: "folder.fill")
            )
            let browseNav = UINavigationController(rootViewController: browseVC)
            controllers.append(browseNav)
        }
        
        // Add maps tab if available
        if manifest.content.features.offlineMaps && controllers.count < 5 {
            let mapsVC = UIViewController() // Placeholder
            mapsVC.view.backgroundColor = .black
            mapsVC.title = "Maps"
            mapsVC.tabBarItem = UITabBarItem(
                title: "Maps",
                image: UIImage(systemName: "map"),
                selectedImage: UIImage(systemName: "map.fill")
            )
            let mapsNav = UINavigationController(rootViewController: mapsVC)
            controllers.append(mapsNav)
        }
        
        // Add more tab if needed
        if manifest.content.features.pillIdentification && controllers.count < 5 {
            let moreVC = UIViewController() // Placeholder
            moreVC.view.backgroundColor = .black
            moreVC.title = "More"
            moreVC.tabBarItem = UITabBarItem(
                title: "More",
                image: UIImage(systemName: "ellipsis"),
                selectedImage: UIImage(systemName: "ellipsis.circle.fill")
            )
            let moreNav = UINavigationController(rootViewController: moreVC)
            controllers.append(moreNav)
        }
        
        viewControllers = controllers
    }
}