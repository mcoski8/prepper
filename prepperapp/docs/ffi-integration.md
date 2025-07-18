# FFI Integration Guide

This document explains how PrepperApp integrates the Rust-based Tantivy search engine into iOS and Android apps.

## Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐
│   iOS App       │     │  Android App    │
│   (Swift)       │     │   (Kotlin)      │
└────────┬────────┘     └────────┬────────┘
         │                       │
    ┌────▼────┐             ┌────▼────┐
    │  Swift  │             │  Kotlin │
    │ Bridge  │             │  Bridge │
    └────┬────┘             └────┬────┘
         │                       │
    ┌────▼────┐             ┌────▼────┐
    │   C     │             │   JNI   │
    │  FFI    │             │ Wrapper │
    └────┬────┘             └────┬────┘
         │                       │
         └───────┬───────────────┘
                 │
            ┌────▼────┐
            │  Rust   │
            │ Tantivy │
            │ Library │
            └─────────┘
```

## iOS Integration (Swift FFI)

### 1. Build Process
```bash
# Build static library for iOS
cd scripts
./build-ios-lib.sh

# Creates:
# - ios/Libraries/libtantivy_mobile.a (universal static library)
# - ios/Libraries/tantivy_mobile.h (C header)
```

### 2. Swift Bridge Architecture

The Swift bridge (`TantivyBridge.swift`) provides:
- Type-safe Swift API
- Async/await support
- Memory management
- Error handling
- Thread safety

```swift
// Example usage
let index = try TantivyBridge.createIndex(at: indexPath)
try await index.addDocument(
    id: "med-001",
    title: "Bleeding Control",
    category: "Medical",
    priority: 5,
    summary: "Stop severe bleeding",
    content: "Apply direct pressure..."
)
try await index.commit()

let results = try await index.search(query: "bleeding", limit: 10)
```

### 3. Memory Management

- Swift owns the index pointer via `OpaquePointer`
- Automatic cleanup in `deinit`
- C strings are properly converted and freed
- Search results are immediately converted to Swift types

### 4. Thread Safety

- Concurrent reads allowed via `DispatchQueue.concurrent`
- Writes use `.barrier` flag for exclusive access
- Tantivy's internal thread safety is preserved

## Android Integration (Kotlin JNI)

### 1. Build Process
```bash
# Build shared libraries for Android
export ANDROID_NDK_HOME=/path/to/ndk
cd scripts
./build-android-lib.sh

# Creates .so files for each architecture:
# - android/app/src/main/jniLibs/arm64-v8a/libtantivy_mobile.so
# - android/app/src/main/jniLibs/armeabi-v7a/libtantivy_mobile.so
# - android/app/src/main/jniLibs/x86_64/libtantivy_mobile.so
# - android/app/src/main/jniLibs/x86/libtantivy_mobile.so
```

### 2. JNI Bridge Architecture

The Kotlin bridge (`TantivyBridge.kt`) provides:
- Coroutine support for async operations
- Type-safe Kotlin API
- Automatic library loading
- Resource management

```kotlin
// Example usage
val index = TantivyBridge.createIndex(indexPath) ?: throw Exception("Failed to create index")
index.addDocument(
    id = "med-001",
    title = "Bleeding Control",
    category = "Medical",
    priority = 5,
    summary = "Stop severe bleeding",
    content = "Apply direct pressure..."
)
index.commit()

val results = index.search("bleeding", limit = 10)
```

### 3. JNI Implementation

The C++ JNI wrapper (`tantivy_jni.cpp`):
- Converts between JNI types and C types
- Manages string encoding (UTF-8)
- Handles object construction
- Provides error codes

### 4. Memory Management

- Kotlin holds index pointer as `Long`
- JNI layer converts between Java/Kotlin and C types
- Strings are properly acquired and released
- Native memory freed when index is closed

## Common Patterns

### Error Handling

Both platforms use result types:
- iOS: Swift `throws` with custom `TantivyError`
- Android: Nullable returns with error codes

### Async Operations

- iOS: `async/await` with `CheckedContinuation`
- Android: Coroutines with `Dispatchers.IO`

### Search Results

Common structure across platforms:
```
SearchResult {
    id: String
    title: String
    category: String
    summary: String
    priority: Int
    score: Float
}
```

## Performance Considerations

### Binary Size
- iOS: ~5-10MB added to app size
- Android: ~3-5MB per architecture

### Memory Usage
- Indexes use memory-mapped files
- Only metadata kept in RAM
- Typical usage: 50-100MB for core index

### Search Performance
- Target: <100ms for any query
- Achieved through:
  - Pre-built indexes
  - FAST fields for quick retrieval
  - Optimized schema design

## Debugging

### iOS
- Enable Tantivy logging: `TantivyBridge.initializeLogging()`
- Logs appear in Xcode console
- Use Instruments for memory profiling

### Android
- Logs appear in Logcat with tag "TantivyMobile"
- Use Android Studio profilers
- Check for JNI warnings in logs

## Testing

### Unit Tests
- iOS: `TantivyBridgeTests.swift`
- Android: Create `TantivyBridgeTest.kt`

### Integration Tests
- Test with real ZIM content
- Verify search performance
- Check memory usage
- Test concurrent access

## Troubleshooting

### Common Issues

1. **Library not found**
   - iOS: Check library is added to project
   - Android: Verify .so files in jniLibs

2. **Crashes on search**
   - Check index is properly initialized
   - Verify commit() was called after indexing
   - Look for memory corruption

3. **Slow performance**
   - Ensure indexes are pre-built
   - Check device has sufficient RAM
   - Verify not indexing on main thread

4. **Build failures**
   - Update Rust toolchain
   - Check NDK version (Android)
   - Verify iOS deployment target

## Future Improvements

1. **Fuzzy Search**
   - Add Levenshtein distance support
   - Configure edit distance threshold

2. **Incremental Indexing**
   - Support partial index updates
   - Background indexing service

3. **Multi-language Support**
   - Add language-specific analyzers
   - Support for non-English content

4. **Index Compression**
   - Implement custom compression
   - Reduce index size further