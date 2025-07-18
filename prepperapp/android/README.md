# PrepperApp Android

Native Android implementation of PrepperApp, optimized for offline survival knowledge access.

## Architecture

- **Language**: Kotlin
- **UI Framework**: Native Android Views (no Compose)
- **Minimum SDK**: 26 (Android 8.0 Oreo)
- **Target SDK**: 34
- **Search**: Tantivy (Rust) via JNI
- **Theme**: Pure black OLED-optimized

## Project Structure

```
android/
├── app/
│   ├── src/main/
│   │   ├── java/com/prepperapp/
│   │   │   ├── MainActivity.kt           # Main search interface
│   │   │   ├── SearchResultAdapter.kt   # RecyclerView adapter
│   │   │   ├── ArticleDetailActivity.kt # Article viewer
│   │   │   └── TantivyBridge.kt        # JNI wrapper for Tantivy
│   │   ├── cpp/
│   │   │   ├── CMakeLists.txt          # Native build config
│   │   │   ├── tantivy_jni.cpp         # JNI implementation
│   │   │   └── include/                # C headers
│   │   ├── res/
│   │   │   ├── layout/                 # UI layouts
│   │   │   ├── values/                 # Strings, themes
│   │   │   └── drawable/               # UI assets
│   │   ├── jniLibs/                    # Native libraries
│   │   └── AndroidManifest.xml
│   └── build.gradle
├── build.gradle
└── settings.gradle
```

## Key Features

### 1. Search-First UI
- Search field always visible at top
- Instant search with 300ms debouncing
- Results show priority indicators
- Keyboard shown on launch

### 2. OLED Optimization
- Pure black backgrounds (#000000)
- No animations or transitions
- White text with opacity variations
- Edge-to-edge display

### 3. Emergency Mode
- Accessible from article view
- Increases font sizes
- Removes non-essential UI
- Optimized for critical situations

### 4. Storage Access
- Uses Storage Access Framework (SAF)
- No MANAGE_EXTERNAL_STORAGE permission
- User grants access to content folder
- Handles ZIM file associations

## Building

### Prerequisites
1. Android Studio Arctic Fox or newer
2. Android NDK (for native code)
3. Rust toolchain with Android targets
4. cargo-ndk installed

### Build Steps

1. Build the Rust library:
```bash
export ANDROID_NDK_HOME=/path/to/ndk
cd scripts
./build-android-lib.sh
```

2. Open project in Android Studio:
   - Import project from `android/` directory
   - Let Gradle sync complete

3. Build and run:
   - Select device/emulator
   - Click Run

## Performance Targets

- App launch to search: <1 second
- Search results: <100ms
- Memory usage: <150MB
- Battery drain: <2% per hour
- APK size: <20MB

## Key Implementation Details

### JNI Integration
- Tantivy Rust library accessed via JNI
- Careful memory management for strings
- Coroutines for async operations
- Thread-safe index access

### Battery Optimization
- No background services
- Wake locks only during indexing
- Efficient RecyclerView with ViewBinding
- Minimal UI redraws

### Material Design
- Material 3 components
- Dark theme only
- Large touch targets (48dp minimum)
- High contrast for visibility

## Testing

Test on real devices for:
- OLED black levels
- Battery consumption
- Search performance
- Memory usage under pressure

Use Android Studio profilers:
- CPU Profiler (search speed)
- Memory Profiler (heap usage)
- Energy Profiler (battery)
- Network Profiler (ensure offline)

## Next Steps

1. Implement content module downloader
2. Add ZIM file support via Kiwix
3. Create background indexing service
4. Add emergency mode enhancements
5. Implement index management UI
6. Add crash reporting (offline)

## Storage Strategy

Following Google Play policies:
- Use Storage Access Framework
- User selects content directory
- Persistent permissions via URI
- No broad storage access

## ProGuard Rules

Add to `proguard-rules.pro`:
```
-keep class com.prepperapp.TantivyBridge { *; }
-keep class com.prepperapp.TantivyBridge$* { *; }
```