# Storage API Documentation

## Overview
The Storage API manages all storage operations including internal device storage, external USB/SD cards, module lifecycle, and space optimization. It provides a unified interface for storage detection, management, and monitoring across iOS and Android platforms.

## Architecture

### Storage Service Structure
```
┌─────────────────────────────────────────────────────────┐
│                    Storage API                           │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │Storage Manager│ │Space Monitor │  │Transfer Service│ │
│  └─────────────┘  └──────────────┘  └───────────────┘ │
├─────────────────────────────────────────────────────────┤
│               Platform Storage Layer                     │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │   iOS Files │  │Android SAF   │  │  File System  │ │
│  └─────────────┘  └──────────────┘  └───────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## API Reference

### StorageService Interface

#### Core Storage Operations
```swift
// iOS Swift
protocol StorageServiceProtocol {
    func getAvailableStorage() async -> [StorageDevice]
    func getStorageInfo(for deviceId: String) -> StorageInfo?
    func requestStorageAccess(for device: StorageDevice) async throws -> Bool
    func copyModule(from source: URL, to destination: StorageLocation) async throws
    func deleteModule(_ moduleId: String, from location: StorageLocation) async throws
    func moveModule(_ moduleId: String, from: StorageLocation, to: StorageLocation) async throws
}

class StorageService: StorageServiceProtocol {
    private let fileManager = FileManager.default
    private let storageMonitor = StorageMonitor()
    
    init() {
        setupStorageObservers()
    }
}
```

```kotlin
// Android Kotlin
interface StorageService {
    suspend fun getAvailableStorage(): List<StorageDevice>
    fun getStorageInfo(deviceId: String): StorageInfo?
    suspend fun requestStorageAccess(device: StorageDevice): Boolean
    suspend fun copyModule(source: Uri, destination: StorageLocation)
    suspend fun deleteModule(moduleId: String, location: StorageLocation)
    suspend fun moveModule(moduleId: String, from: StorageLocation, to: StorageLocation)
}

class StorageServiceImpl(
    private val context: Context
) : StorageService {
    private val contentResolver = context.contentResolver
    private val storageManager = context.getSystemService(StorageManager::class.java)
}
```

### Storage Models

#### Storage Device
```swift
struct StorageDevice: Identifiable {
    let id: String
    let name: String
    let type: StorageType
    let totalSpace: Int64      // Bytes
    let availableSpace: Int64  // Bytes
    let isRemovable: Bool
    let isWritable: Bool
    let path: URL?             // nil for restricted devices
    let requiresPermission: Bool
}

enum StorageType: String, CaseIterable {
    case internal = "internal"
    case sdCard = "sd_card"
    case usbDrive = "usb_drive"
    case networkAttached = "nas"
    case cloud = "cloud"        // Future
}

struct StorageLocation {
    let deviceId: String
    let path: String
    let type: StorageType
    
    var fullPath: String {
        "\(deviceId):\(path)"
    }
}
```

#### Storage Info
```swift
struct StorageInfo {
    let device: StorageDevice
    let usedSpace: Int64
    let modules: [ModuleStorageInfo]
    let cacheSize: Int64
    let lastUpdated: Date
    
    var freeSpace: Int64 {
        device.availableSpace
    }
    
    var usagePercentage: Double {
        Double(usedSpace) / Double(device.totalSpace) * 100
    }
}

struct ModuleStorageInfo {
    let moduleId: String
    let name: String
    let size: Int64
    let location: StorageLocation
    let lastAccessed: Date
    let accessCount: Int
}
```

### Storage Detection

#### iOS External Storage Detection
```swift
extension StorageService {
    func setupStorageObservers() {
        // Monitor for external devices
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVolumeChange),
            name: .NSWorkspaceDidMountNotification,
            object: nil
        )
        
        // iOS 13+ external drive support
        if #available(iOS 13.0, *) {
            observeExternalDrives()
        }
    }
    
    @available(iOS 13.0, *)
    private func observeExternalDrives() {
        let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        
        // Check for USB drives via Files app
        let coordinator = NSFileCoordinator()
        var error: NSError?
        
        coordinator.coordinate(
            readingItemAt: documentsURL,
            options: .forUploading,
            error: &error
        ) { url in
            self.scanForExternalDrives(at: url)
        }
    }
    
    private func scanForExternalDrives(at url: URL) {
        do {
            let urls = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.volumeNameKey, .volumeIdentifierKey],
                options: .skipsHiddenFiles
            )
            
            for deviceURL in urls {
                if let device = createStorageDevice(from: deviceURL) {
                    detectedDevices.append(device)
                }
            }
        } catch {
            print("Error scanning for drives: \(error)")
        }
    }
}
```

#### Android Storage Access Framework
```kotlin
class StorageServiceImpl : StorageService {
    
    override suspend fun getAvailableStorage(): List<StorageDevice> = withContext(Dispatchers.IO) {
        val devices = mutableListOf<StorageDevice>()
        
        // Internal storage
        devices.add(getInternalStorage())
        
        // External storage (SD cards)
        devices.addAll(getExternalStorageDevices())
        
        // USB OTG devices
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            devices.addAll(getUsbDevices())
        }
        
        devices
    }
    
    private fun getExternalStorageDevices(): List<StorageDevice> {
        val devices = mutableListOf<StorageDevice>()
        
        // Get all external storage volumes
        val externalDirs = ContextCompat.getExternalFilesDirs(context, null)
        
        externalDirs.forEach { file ->
            if (file != null && Environment.isExternalStorageRemovable(file)) {
                val statFs = StatFs(file.path)
                devices.add(
                    StorageDevice(
                        id = file.absolutePath.hashCode().toString(),
                        name = "SD Card",
                        type = StorageType.SD_CARD,
                        totalSpace = statFs.totalBytes,
                        availableSpace = statFs.availableBytes,
                        isRemovable = true,
                        isWritable = file.canWrite(),
                        path = Uri.fromFile(file),
                        requiresPermission = false
                    )
                )
            }
        }
        
        return devices
    }
    
    @RequiresApi(Build.VERSION_CODES.N)
    private fun getUsbDevices(): List<StorageDevice> {
        val devices = mutableListOf<StorageDevice>()
        val storageVolumes = storageManager.storageVolumes
        
        storageVolumes.forEach { volume ->
            if (volume.isRemovable && !volume.isPrimary) {
                // This might be a USB device
                val intent = volume.createAccessIntent(null)
                if (intent != null) {
                    devices.add(
                        StorageDevice(
                            id = volume.uuid ?: volume.hashCode().toString(),
                            name = volume.getDescription(context) ?: "USB Drive",
                            type = StorageType.USB_DRIVE,
                            totalSpace = 0, // Will be updated after access
                            availableSpace = 0,
                            isRemovable = true,
                            isWritable = false, // Until permission granted
                            path = null,
                            requiresPermission = true
                        )
                    )
                }
            }
        }
        
        return devices
    }
}
```

### Storage Access Permission

#### Request Access (Android SAF)
```kotlin
class StorageAccessManager(private val activity: Activity) {
    
    companion object {
        private const val REQUEST_CODE_STORAGE_ACCESS = 1001
    }
    
    suspend fun requestStorageAccess(device: StorageDevice): Boolean = suspendCoroutine { cont ->
        if (!device.requiresPermission) {
            cont.resume(true)
            return@suspendCoroutine
        }
        
        // Create intent for Storage Access Framework
        val intent = when (device.type) {
            StorageType.USB_DRIVE -> {
                Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                    putExtra(DocumentsContract.EXTRA_INITIAL_URI, device.path)
                }
            }
            else -> Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        }
        
        // Store continuation for result callback
        pendingContinuation = cont
        
        // Launch intent
        activity.startActivityForResult(intent, REQUEST_CODE_STORAGE_ACCESS)
    }
    
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_CODE_STORAGE_ACCESS) {
            val granted = resultCode == Activity.RESULT_OK && data?.data != null
            
            if (granted) {
                // Persist permissions
                val uri = data!!.data!!
                val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                activity.contentResolver.takePersistableUriPermission(uri, takeFlags)
            }
            
            pendingContinuation?.resume(granted)
            pendingContinuation = null
        }
    }
}
```

### Module Transfer Operations

#### Copy Module to External Storage
```swift
class ModuleTransferService {
    
    func copyModule(
        moduleId: String,
        to destination: StorageLocation,
        progress: @escaping (Double) -> Void
    ) async throws {
        
        // Get module info
        guard let module = getModule(moduleId) else {
            throw StorageError.moduleNotFound(moduleId)
        }
        
        // Check space
        let requiredSpace = module.size + module.indexSize
        guard hasSpace(requiredSpace, at: destination) else {
            throw StorageError.insufficientSpace(
                required: requiredSpace,
                available: getAvailableSpace(at: destination)
            )
        }
        
        // Create destination directory
        let destURL = createModuleDirectory(for: moduleId, at: destination)
        
        // Copy files with progress
        let files = [
            (module.contentPath, destURL.appendingPathComponent("content.zim")),
            (module.indexPath, destURL.appendingPathComponent("index.tantivy"))
        ]
        
        for (index, (source, dest)) in files.enumerated() {
            try await copyFile(from: source, to: dest) { fileProgress in
                let totalProgress = (Double(index) + fileProgress) / Double(files.count)
                progress(totalProgress)
            }
        }
        
        // Update registry
        updateModuleLocation(moduleId, location: destination)
    }
    
    private func copyFile(
        from source: URL,
        to destination: URL,
        progress: @escaping (Double) -> Void
    ) async throws {
        
        let fileSize = try FileManager.default.attributesOfItem(at: source)[.size] as! Int64
        let bufferSize = 1024 * 1024 // 1MB chunks
        
        let input = try FileHandle(forReadingFrom: source)
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let output = try FileHandle(forWritingTo: destination)
        
        defer {
            input.closeFile()
            output.closeFile()
        }
        
        var bytesWritten: Int64 = 0
        
        while true {
            let data = input.readData(ofLength: bufferSize)
            if data.isEmpty { break }
            
            output.write(data)
            bytesWritten += Int64(data.count)
            
            await MainActor.run {
                progress(Double(bytesWritten) / Double(fileSize))
            }
        }
    }
}
```

### Storage Monitoring

#### Space Monitoring
```swift
class StorageMonitor {
    private let lowSpaceThreshold: Int64 = 500 * 1024 * 1024 // 500MB
    private let criticalSpaceThreshold: Int64 = 100 * 1024 * 1024 // 100MB
    private var timer: Timer?
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.checkStorageSpace()
        }
    }
    
    private func checkStorageSpace() {
        let devices = StorageService.shared.getAvailableStorage()
        
        for device in devices {
            if device.availableSpace < criticalSpaceThreshold {
                sendNotification(.criticalSpace, device: device)
                triggerEmergencyCleanup(device: device)
            } else if device.availableSpace < lowSpaceThreshold {
                sendNotification(.lowSpace, device: device)
                suggestCleanup(device: device)
            }
        }
    }
    
    private func triggerEmergencyCleanup(device: StorageDevice) {
        // Clear caches
        CacheManager.shared.clearAll()
        
        // Remove least used modules
        let modules = getModules(on: device)
            .sorted { $0.lastAccessed < $1.lastAccessed }
        
        var freedSpace: Int64 = 0
        for module in modules {
            if freedSpace > lowSpaceThreshold { break }
            
            if module.accessCount == 0 {
                deleteModule(module.id)
                freedSpace += module.size
            }
        }
    }
}
```

### Cache Management

#### Smart Cache Strategy
```swift
class CacheManager {
    private let maxCacheSize: Int64 = 200 * 1024 * 1024 // 200MB
    private var currentCacheSize: Int64 = 0
    
    struct CachePolicy {
        let maxAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
        let maxSize: Int64 = 200 * 1024 * 1024
        let evictionStrategy: EvictionStrategy = .leastRecentlyUsed
    }
    
    enum EvictionStrategy {
        case leastRecentlyUsed
        case leastFrequentlyUsed
        case largest
        case oldest
    }
    
    func cacheArticle(_ article: Article) {
        let size = Int64(article.content.utf8.count)
        
        // Check if we need to evict
        while currentCacheSize + size > maxCacheSize {
            evictOne()
        }
        
        // Add to cache
        let cacheEntry = CacheEntry(
            article: article,
            size: size,
            accessCount: 1,
            lastAccessed: Date()
        )
        
        saveToDisk(cacheEntry)
        currentCacheSize += size
    }
    
    private func evictOne() {
        let entries = loadAllCacheEntries()
        
        guard let victim = selectVictim(from: entries) else { return }
        
        deleteFromDisk(victim)
        currentCacheSize -= victim.size
    }
}
```

### Error Handling

#### Storage Errors
```swift
enum StorageError: LocalizedError {
    case deviceNotFound(String)
    case accessDenied(String)
    case insufficientSpace(required: Int64, available: Int64)
    case moduleNotFound(String)
    case transferFailed(String)
    case corruptedModule(String)
    case unsupportedDevice(StorageType)
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound(let id):
            return "Storage device not found: \(id)"
        case .accessDenied(let device):
            return "Access denied to storage device: \(device)"
        case .insufficientSpace(let required, let available):
            let reqMB = required / 1024 / 1024
            let availMB = available / 1024 / 1024
            return "Insufficient space: need \(reqMB)MB, have \(availMB)MB"
        case .moduleNotFound(let id):
            return "Module not found: \(id)"
        case .transferFailed(let reason):
            return "Transfer failed: \(reason)"
        case .corruptedModule(let id):
            return "Module corrupted: \(id)"
        case .unsupportedDevice(let type):
            return "Unsupported storage type: \(type)"
        }
    }
}
```

### Testing

#### Storage Tests
```swift
class StorageAPITests: XCTestCase {
    
    func testInternalStorageDetection() async {
        let service = StorageService()
        let devices = await service.getAvailableStorage()
        
        XCTAssertTrue(devices.contains { $0.type == .internal })
    }
    
    func testSpaceCalculation() {
        let device = StorageDevice(
            id: "test",
            name: "Test",
            type: .internal,
            totalSpace: 1000,
            availableSpace: 400,
            isRemovable: false,
            isWritable: true,
            path: nil,
            requiresPermission: false
        )
        
        let info = StorageInfo(
            device: device,
            usedSpace: 600,
            modules: [],
            cacheSize: 100,
            lastUpdated: Date()
        )
        
        XCTAssertEqual(info.usagePercentage, 60.0)
        XCTAssertEqual(info.freeSpace, 400)
    }
    
    func testModuleTransfer() async throws {
        let service = ModuleTransferService()
        
        // Create test module
        let moduleId = "test-module"
        let source = createTestModule(id: moduleId, size: 1024 * 1024)
        
        // Transfer to external
        let destination = StorageLocation(
            deviceId: "external",
            path: "/modules",
            type: .sdCard
        )
        
        var lastProgress: Double = 0
        try await service.copyModule(
            moduleId: moduleId,
            to: destination
        ) { progress in
            XCTAssertGreaterThanOrEqual(progress, lastProgress)
            lastProgress = progress
        }
        
        XCTAssertEqual(lastProgress, 1.0)
    }
}
```

## Performance Guidelines

### Optimization Strategies
1. **Batch Operations**: Group multiple file operations
2. **Background Processing**: Use background queues for transfers
3. **Progress Reporting**: Update UI at reasonable intervals (not every byte)
4. **Memory Mapping**: Use for large file reads
5. **Chunk Transfers**: Transfer large files in chunks to allow cancellation

### Target Metrics
| Operation | Target | Maximum |
|-----------|--------|---------|
| Device detection | <500ms | 1s |
| Space calculation | <100ms | 200ms |
| Module transfer (per GB) | <30s | 60s |
| Cache cleanup | <2s | 5s |
| Permission request | <100ms | 500ms |