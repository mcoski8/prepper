/**
 * PrepperApp Tantivy FFI Bindings
 * 
 * This header defines the C interface for the Tantivy search engine
 * to be used by both iOS (Swift) and Android (Kotlin) native code.
 * 
 * CRITICAL: All functions must handle errors gracefully and never panic
 * across the FFI boundary.
 * 
 * Updated to use JSON-based C API as recommended by Gemini 2.5 Pro
 */

#ifndef PREPPERAPP_TANTIVY_BINDINGS_H
#define PREPPERAPP_TANTIVY_BINDINGS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque type for the searcher
typedef struct TantivySearcher TantivySearcher;

/**
 * Initialize a searcher from the given index path.
 * 
 * @param path Path to the index directory
 * @return JSON string: {"success": {"searcher_ptr": 12345}} or {"error": "message"}
 *         The caller must free the returned string using free_string()
 */
char* init_searcher(const char* path);

/**
 * Execute a search query.
 * 
 * @param searcher_ptr Pointer to the searcher (from init_searcher)
 * @param query Search query string
 * @param limit Maximum number of results to return
 * @param offset Number of results to skip (for pagination)
 * @return JSON string: {"success": [{"doc_id": "...", "score": 1.23, "title": "...", "snippet": "..."}]}
 *         or {"error": "message"}
 *         The caller must free the returned string using free_string()
 */
char* search(const TantivySearcher* searcher_ptr, const char* query, uint32_t limit, uint32_t offset);

/**
 * Free a string returned by this library.
 * 
 * @param s String to free
 */
void free_string(char* s);

/**
 * Close and free a searcher.
 * 
 * @param searcher_ptr Searcher to close
 */
void close_searcher(TantivySearcher* searcher_ptr);

#ifdef __cplusplus
}
#endif

#endif // PREPPERAPP_TANTIVY_BINDINGS_H