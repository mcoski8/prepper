# Tantivy Mobile Library

This library provides C FFI bindings for Tantivy search engine, optimized for iOS and Android.

## Features

- Minimal C API surface for easy integration
- Thread-safe index management
- Mobile-optimized memory usage
- Platform-specific logging (iOS: oslog, Android: logcat)
- Fast MMAP-based index access
- Sub-100ms search performance

## API Overview

### Core Functions

```c
// Initialize logging
void tantivy_init_logging(void);

// Index management
void* tantivy_create_index(const char* path);
void* tantivy_open_index(const char* path);
void tantivy_free_index(void* index_ptr);

// Document operations
int32_t tantivy_add_document(
    void* index_ptr,
    const char* id,
    const char* title,
    const char* category,
    uint64_t priority,
    const char* summary,
    const char* content
);
int32_t tantivy_commit(void* index_ptr);

// Search
SearchResults* tantivy_search(
    void* index_ptr,
    const char* query,
    size_t limit
);
void tantivy_free_search_results(SearchResults* results);

// Statistics
IndexStats tantivy_get_index_stats(void* index_ptr);
```

### Error Codes

- `TANTIVY_SUCCESS` (0): Operation successful
- `TANTIVY_ERROR_INVALID_PARAM` (-1): Invalid parameter
- `TANTIVY_ERROR_INDEX_CREATION` (-2): Failed to create index
- `TANTIVY_ERROR_SEARCH_FAILED` (-3): Search operation failed
- `TANTIVY_ERROR_INDEXING_FAILED` (-4): Document indexing failed

## Building

### iOS
```bash
cd scripts
./build-ios-lib.sh
```

This creates a universal static library at `ios/Libraries/libtantivy_mobile.a`.

### Android
```bash
export ANDROID_NDK_HOME=/path/to/ndk
cd scripts
./build-android-lib.sh
```

This creates `.so` files for all Android architectures in `android/app/src/main/jniLibs/`.

## Integration

### iOS (Swift)

1. Add `libtantivy_mobile.a` to your Xcode project
2. Create a bridging header with:
   ```c
   #import "tantivy_mobile.h"
   ```
3. Use the Swift wrapper (see `ios/TantivyBridge.swift`)

### Android (Kotlin)

1. The `.so` files are automatically included via JNI
2. Load the library:
   ```kotlin
   companion object {
       init {
           System.loadLibrary("tantivy_mobile")
       }
   }
   ```
3. Use the Kotlin wrapper (see `android/TantivyBridge.kt`)

## Memory Management

- Always call `tantivy_free_search_results()` after processing search results
- Call `tantivy_free_index()` when done with an index
- The library uses reference counting internally for thread safety
- Indexes use memory-mapped files for efficient memory usage

## Performance Optimization

- Commit batches of documents rather than individual ones
- Use `tantivy_get_index_stats()` to monitor index growth
- Search operations are thread-safe and can be called concurrently
- The library is optimized for size (`opt-level = "z"`) to reduce binary footprint

## Thread Safety

- All functions are thread-safe
- Multiple threads can search simultaneously
- Only one thread should write/commit at a time
- The internal reader automatically reloads after commits