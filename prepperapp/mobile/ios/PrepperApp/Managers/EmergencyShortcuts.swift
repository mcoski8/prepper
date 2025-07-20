import UIKit
import CoreMotion

class EmergencyShortcuts {
    static let shared = EmergencyShortcuts()
    
    private let motionManager = CMMotionManager()
    private var volumeButtonPressCount = 0
    private var volumeButtonTimer: Timer?
    private var lastShakeTime: Date?
    
    private init() {}
    
    // MARK: - Public Methods
    
    func registerShortcuts() {
        registerShakeDetection()
        registerVolumeButtonDetection()
    }
    
    // MARK: - Shake Detection
    
    private func registerShakeDetection() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let data = data else { return }
            
            let acceleration = data.acceleration
            let magnitude = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
            
            // Detect strong shake (magnitude > 2.5g)
            if magnitude > 2.5 {
                self?.handleShakeDetected()
            }
        }
    }
    
    private func handleShakeDetected() {
        // Debounce shake detection (max once per 2 seconds)
        let now = Date()
        if let lastShake = lastShakeTime, now.timeIntervalSince(lastShake) < 2.0 {
            return
        }
        lastShakeTime = now
        
        // Navigate to hemorrhage control
        navigateToEmergencyArticle(EmergencyArticle.hemorrhageControl)
    }
    
    // MARK: - Volume Button Detection
    
    private func registerVolumeButtonDetection() {
        // Monitor audio session for volume changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(volumeChanged),
            name: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil
        )
    }
    
    @objc private func volumeChanged(notification: NSNotification) {
        guard let info = notification.userInfo,
              let volume = info["AVSystemController_AudioVolumeNotificationParameter"] as? Float else {
            return
        }
        
        // Detect volume down press (volume decreased)
        if volume < 0.5 {
            volumeButtonPressCount += 1
            
            // Reset timer
            volumeButtonTimer?.invalidate()
            volumeButtonTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.volumeButtonPressCount = 0
            }
            
            // Check for 3 presses
            if volumeButtonPressCount >= 3 {
                volumeButtonPressCount = 0
                navigateToEmergencyArticle(EmergencyArticle.cprGuide)
            }
        }
    }
    
    // MARK: - Navigation
    
    private func navigateToEmergencyArticle(_ articleId: String) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootVC = window.rootViewController as? UINavigationController else {
                return
            }
            
            // Create article view controller
            let articleVC = ArticleViewController(articleId: articleId)
            
            // Push without animation for instant access
            rootVC.pushViewController(articleVC, animated: false)
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }
    }
}