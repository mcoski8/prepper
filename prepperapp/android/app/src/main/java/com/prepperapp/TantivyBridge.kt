package com.prepperapp

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

object TantivyBridge {
    
    // Native method declarations
    external fun nativeInitLogging()
    external fun nativeCreateIndex(path: String): Long
    external fun nativeOpenIndex(path: String): Long
    external fun nativeAddDocument(
        indexPtr: Long,
        id: String,
        title: String,
        category: String,
        priority: Int,
        summary: String,
        content: String
    ): Int
    external fun nativeCommit(indexPtr: Long): Int
    external fun nativeSearch(
        indexPtr: Long,
        query: String,
        limit: Int
    ): SearchResultsNative?
    external fun nativeFreeSearchResults(resultsPtr: Long)
    external fun nativeFreeIndex(indexPtr: Long)
    external fun nativeGetIndexStats(indexPtr: Long): IndexStats
    
    // Data classes for JNI
    data class SearchResultsNative(
        val results: Array<SearchResultNative>,
        val searchTimeMs: Long
    )
    
    data class SearchResultNative(
        val id: String,
        val title: String,
        val category: String,
        val summary: String,
        val priority: Int,
        val score: Float
    )
    
    data class IndexStats(
        val numDocs: Long,
        val indexSizeBytes: Long
    )
    
    // High-level Kotlin API
    class Index(private val indexPtr: Long) {
        
        suspend fun addDocument(
            id: String,
            title: String,
            category: String,
            priority: Int,
            summary: String,
            content: String
        ): Boolean = withContext(Dispatchers.IO) {
            val result = nativeAddDocument(indexPtr, id, title, category, priority, summary, content)
            result == 0
        }
        
        suspend fun commit(): Boolean = withContext(Dispatchers.IO) {
            val result = nativeCommit(indexPtr)
            result == 0
        }
        
        suspend fun search(query: String, limit: Int = 10): List<SearchResult> = withContext(Dispatchers.IO) {
            val nativeResults = nativeSearch(indexPtr, query, limit)
            nativeResults?.results?.map { native ->
                SearchResult(
                    id = native.id,
                    title = native.title,
                    category = native.category,
                    summary = native.summary,
                    priority = native.priority,
                    score = native.score
                )
            } ?: emptyList()
        }
        
        suspend fun getStats(): IndexStats = withContext(Dispatchers.IO) {
            nativeGetIndexStats(indexPtr)
        }
        
        fun close() {
            nativeFreeIndex(indexPtr)
        }
    }
    
    // Public API
    fun initLogging() {
        nativeInitLogging()
    }
    
    suspend fun createIndex(path: String): Index? = withContext(Dispatchers.IO) {
        val ptr = nativeCreateIndex(path)
        if (ptr != 0L) Index(ptr) else null
    }
    
    suspend fun openIndex(path: String): Index? = withContext(Dispatchers.IO) {
        val ptr = nativeOpenIndex(path)
        if (ptr != 0L) Index(ptr) else null
    }
}