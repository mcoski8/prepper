# Content-Agnostic Architecture

**Created:** July 19, 2025  
**Purpose:** Design mobile apps that work with any content size/structure

## Overview

PrepperApp's mobile applications must handle content ranging from 10MB test bundles to 3GB Tier 1 bundles to 220GB external archives. This document defines how we build apps that adapt to any content configuration.

## Core Principles

1. **No Hardcoded Assumptions**: Apps discover content at runtime
2. **Progressive Enhancement**: More content = more features, not failures
3. **Flexible Storage**: Support internal, SD card, and external USB storage
4. **Dynamic UI**: Interface adapts based on available content
5. **Forward Compatible**: Today's app works with tomorrow's content

## Content Discovery System

### Manifest-Driven Architecture

Every content bundle includes a `manifest.json`:

```json
{
  "version": "1.0",
  "type": "tier1|tier2|tier3|test",
  "name": "Human-readable name",
  "size_mb": 249,
  "requires_external_storage": false,
  "content": {
    "databases": ["medical.db", "survival.db"],
    "indexes": ["tantivy_medical", "tantivy_survival"],
    "categories": ["medical", "water", "shelter", "signaling"],
    "article_count": 9076,
    "priority_levels": [0, 1, 2],
    "features": {
      "offline_maps": false,
      "plant_identification": false,
      "pill_identification": true
    }
  }
}
```

### Storage Locations (Priority Order)

1. **Internal App Storage**
   - `/data/app/com.prepperapp/content/`
   - Always available, limited size
   - For test bundles and Tier 1 core

2. **SD Card** (Android) / App Documents (iOS)
   - `/sdcard/PrepperApp/content/`
   - For Tier 2 modules (1-5GB each)
   - Check permissions first

3. **External USB Storage**
   - `/mnt/usb/PrepperApp/content/`
   - For Tier 3 archive (220GB)
   - Detected via USB host APIs

## Content Loading Strategy

```kotlin
// Android example
class ContentManager {
    fun discoverContent(): List<ContentBundle> {
        val bundles = mutableListOf<ContentBundle>()
        
        // 1. Check internal storage
        bundles.addAll(scanDirectory(internalContentDir))
        
        // 2. Check SD card if available
        if (hasStoragePermission() && sdCardAvailable()) {
            bundles.addAll(scanDirectory(sdCardContentDir))
        }
        
        // 3. Check USB drives
        usbManager.getAttachedDevices().forEach { device ->
            bundles.addAll(scanUsbDevice(device))
        }
        
        return bundles.sortedBy { it.priority }
    }
}
```

## Database Abstraction Layer

### Unified Content Interface

```kotlin
interface ContentProvider {
    fun search(query: String): List<Article>
    fun getArticle(id: String): Article?
    fun getCategories(): List<Category>
    fun getByPriority(level: Int): List<Article>
}

class MultiSourceContentProvider(
    private val bundles: List<ContentBundle>
) : ContentProvider {
    // Federated search across all available bundles
    override fun search(query: String): List<Article> {
        return bundles
            .flatMap { it.search(query) }
            .sortedBy { it.priority }
            .take(50)
    }
}
```

## UI Adaptation System

### Dynamic Feature Flags

The UI enables/disables features based on available content:

```swift
// iOS example
class MainViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Adapt UI based on content
        let content = ContentManager.shared.availableContent
        
        // Only show maps if available
        mapButton.isHidden = !content.hasFeature(.offlineMaps)
        
        // Only show pill ID if available  
        pillIdButton.isHidden = !content.hasFeature(.pillIdentification)
        
        // Adjust search placeholder
        searchBar.placeholder = content.searchPlaceholder
    }
}
```

### Content-Aware Navigation

```kotlin
// Bottom navigation adapts to available content
class MainActivity : AppCompatActivity() {
    private fun setupBottomNav() {
        val menu = bottomNav.menu
        menu.clear()
        
        // Always show search and emergency
        menu.add("Search")
        menu.add("Emergency")
        
        // Conditionally add based on content
        if (contentManager.hasCategory("medical")) {
            menu.add("Medical")
        }
        if (contentManager.hasCategory("maps")) {
            menu.add("Maps")
        }
        if (contentManager.hasTier3Content()) {
            menu.add("Library")
        }
    }
}
```

## Progressive Content Loading

### Tier 1: Core (Always Available)
- Loads into memory for instant access
- Powers emergency quick-actions
- No loading screens for critical info

### Tier 2: Modules (On-Demand)
- Lazy-loaded as needed
- Cached in app storage
- Progress indicators for first access

### Tier 3: Archive (External Browse)
- Never fully loaded
- Stream content as needed
- Show "Connect External Storage" when not available

## Migration Path

As content evolves, apps remain compatible:

1. **Version 1.0**: Ships with test content (50KB)
2. **Version 1.1**: Real Tier 1 bundle (2-3GB)
3. **Version 1.2**: Tier 2 modules available
4. **Version 2.0**: Full Tier 3 support

The same app binary handles all configurations!

## Error Handling

### Graceful Degradation

```kotlin
fun loadContent() {
    try {
        // Try to load optimal content
        loadTier1Bundle()
    } catch (e: ContentNotFoundException) {
        // Fall back to test content
        loadTestBundle()
        showMessage("Using limited content. Download full bundle for complete access.")
    }
}
```

## Implementation Checklist

- [ ] Create manifest.json for test bundle
- [ ] Build ContentManager discovery system
- [ ] Implement storage permission handling
- [ ] Create database abstraction layer
- [ ] Build dynamic UI system
- [ ] Add external storage detection
- [ ] Implement federated search
- [ ] Create content download manager
- [ ] Add offline/online content sync

## Benefits

1. **Development Speed**: Start with tiny test bundle
2. **User Choice**: Users control storage usage
3. **Future Proof**: Add new content types without app updates
4. **Reliability**: Always works with whatever content exists
5. **Performance**: Only load what's needed

This architecture ensures PrepperApp works on any device with any amount of content, from a 50KB test bundle to a 220GB complete archive.