/**
 * PrepperApp Tantivy FFI Bindings
 * 
 * This header defines the C interface for the Tantivy search engine
 * to be used by both iOS (Swift) and Android (Kotlin) native code.
 * 
 * CRITICAL: All functions must handle errors gracefully and never panic
 * across the FFI boundary.
 */

#ifndef PREPPERAPP_TANTIVY_BINDINGS_H
#define PREPPERAPP_TANTIVY_BINDINGS_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Error codes
typedef enum {
    TANTIVY_OK = 0,
    TANTIVY_ERROR_INVALID_PATH = 1,
    TANTIVY_ERROR_INDEX_CORRUPT = 2,
    TANTIVY_ERROR_QUERY_PARSE = 3,
    TANTIVY_ERROR_OUT_OF_MEMORY = 4,
    TANTIVY_ERROR_UNKNOWN = 99
} TantivyError;

// Search result structure (C-compatible)
typedef struct {
    char* article_id;      // Article ID (null-terminated)
    char* title;           // Article title (null-terminated)
    char* snippet;         // Search snippet (null-terminated)
    float score;           // Relevance score (0.0 - 1.0)
    uint32_t priority;     // P0=0, P1=1, P2=2
} SearchResult;

// Search results collection
typedef struct {
    SearchResult* results;  // Array of results
    uint32_t count;        // Number of results
    uint32_t total_hits;   // Total hits (may be > count)
} SearchResults;

// Index handle (opaque pointer)
typedef struct TantivyIndex TantivyIndex;

/**
 * Initialize a Tantivy index from the given path.
 * 
 * @param index_path Path to the index directory
 * @param handle_out Output parameter for the index handle
 * @return Error code (TANTIVY_OK on success)
 */
TantivyError tantivy_index_open(const char* index_path, TantivyIndex** handle_out);

/**
 * Close and free a Tantivy index.
 * 
 * @param handle Index handle to close
 */
void tantivy_index_close(TantivyIndex* handle);

/**
 * Search the index with a query string.
 * 
 * @param handle Index handle
 * @param query Search query (boolean syntax supported)
 * @param max_results Maximum number of results to return
 * @param results_out Output parameter for search results
 * @return Error code (TANTIVY_OK on success)
 */
TantivyError tantivy_search(
    TantivyIndex* handle,
    const char* query,
    uint32_t max_results,
    SearchResults** results_out
);

/**
 * Free search results allocated by tantivy_search.
 * 
 * @param results Results to free
 */
void tantivy_free_results(SearchResults* results);

/**
 * Get a human-readable error message for an error code.
 * 
 * @param error Error code
 * @return Error message (static string, do not free)
 */
const char* tantivy_error_message(TantivyError error);

/**
 * Check if the index is healthy and can be searched.
 * 
 * @param handle Index handle
 * @return true if healthy, false otherwise
 */
bool tantivy_index_is_healthy(TantivyIndex* handle);

/**
 * Get index statistics.
 * 
 * @param handle Index handle
 * @param doc_count_out Output parameter for document count
 * @param index_size_bytes_out Output parameter for index size
 * @return Error code (TANTIVY_OK on success)
 */
TantivyError tantivy_index_stats(
    TantivyIndex* handle,
    uint64_t* doc_count_out,
    uint64_t* index_size_bytes_out
);

#ifdef __cplusplus
}
#endif

#endif // PREPPERAPP_TANTIVY_BINDINGS_H