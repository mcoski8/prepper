package com.prepperapp

import android.content.Context
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString
import java.io.File
import java.io.FileOutputStream

// MARK: - Models

/** Matches the Rust `MultiSearchResultItem` */
@Serializable
data class SearchResult(
    val doc_id: String,
    val title: String,
    val summary: String,
    val score: Float,
    val module: String
)

/** Configuration for search */
@Serializable
data class SearchConfig(
    val limit: Int = 20,
    val weights: Map<String, Float>? = null,
    val module_filter: List<String>? = null
)

/** Module statistics */
@Serializable
data class ModuleStats(
    val name: String,
    val num_docs: Long,
    val estimated_size_bytes: Long
)

// MARK: - SearchService

/**
 * Singleton service for managing search functionality
 */
object SearchService {
    private const val TAG = "SearchService"
    private const val LIBRARY_NAME = "tantivy_mobile"
    
    private var managerPtr: Long = 0L
    private val loadedModules = mutableSetOf<String>()
    
    // Observable state
    private val _isReady = MutableStateFlow(false)
    val isReady = _isReady.asStateFlow()
    
    // JSON configuration
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    
    // FFI function declarations
    private external fun init_multi_manager(): Long
    private external fun destroy_multi_manager(managerPtr: Long)
    private external fun multi_manager_load_index(managerPtr: Long, name: String, path: String): Int
    private external fun multi_manager_unload_index(managerPtr: Long, name: String): Int
    private external fun multi_manager_reload_index(managerPtr: Long, name: String): Int
    private external fun multi_manager_search(managerPtr: Long, query: String, configJson: String?): String?
    private external fun multi_manager_get_stats(managerPtr: Long): String?
    private external fun free_rust_string(ptr: Long)
    
    init {
        try {
            System.loadLibrary(LIBRARY_NAME)
            managerPtr = init_multi_manager()
            
            if (managerPtr != 0L) {
                Log.d(TAG, "Multi-search manager initialized successfully")
            } else {
                Log.e(TAG, "Failed to initialize multi-search manager")
            }
        } catch (e: UnsatisfiedLinkError) {
            Log.e(TAG, "Failed to load native library", e)
        }
    }
    
    /**
     * Clean up resources when no longer needed
     */
    fun close() {
        if (managerPtr != 0L) {
            destroy_multi_manager(managerPtr)
            managerPtr = 0L
            loadedModules.clear()
            _isReady.value = false
        }
    }
    
    // MARK: - Index Management
    
    /**
     * Prepares the core index on first launch
     */
    suspend fun prepareCoreIndex(context: Context) = withContext(Dispatchers.IO) {
        val indexesDir = File(context.filesDir, "TantivyIndexes")
        val coreIndexDir = File(indexesDir, "core")
        
        // Check if index already exists
        if (coreIndexDir.exists() && coreIndexDir.isDirectory) {
            // Load existing index
            val loaded = loadIndex("core", coreIndexDir.absolutePath)
            if (loaded) {
                _isReady.value = true
                Log.d(TAG, "Core index loaded from disk")
            }
            return@withContext
        }
        
        // Copy from assets if first launch
        try {
            coreIndexDir.mkdirs()
            copyAssetFolder(context.assets, "core_index", coreIndexDir.absolutePath)
            
            // Load the index
            val loaded = loadIndex("core", coreIndexDir.absolutePath)
            if (loaded) {
                _isReady.value = true
                Log.d(TAG, "Core index copied and loaded successfully")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error preparing core index", e)
        }
    }
    
    /**
     * Recursively copy asset folder to file system
     */
    private fun copyAssetFolder(
        assetManager: android.content.res.AssetManager,
        fromAssetPath: String,
        toPath: String
    ) {
        val files = assetManager.list(fromAssetPath) ?: return
        File(toPath).mkdirs()
        
        for (file in files) {
            val fromPath = "$fromAssetPath/$file"
            val toFile = File(toPath, file)
            
            val subFiles = assetManager.list(fromPath)
            if (subFiles != null && subFiles.isNotEmpty()) {
                // It's a directory
                copyAssetFolder(assetManager, fromPath, toFile.absolutePath)
            } else {
                // It's a file
                assetManager.open(fromPath).use { input ->
                    FileOutputStream(toFile).use { output ->
                        input.copyTo(output)
                    }
                }
            }
        }
    }
    
    /**
     * Loads an index module
     */
    suspend fun loadIndex(name: String, path: String): Boolean = withContext(Dispatchers.IO) {
        if (managerPtr == 0L) return@withContext false
        
        val result = multi_manager_load_index(managerPtr, name, path)
        if (result == 0) {
            loadedModules.add(name)
            Log.d(TAG, "Loaded module '$name' from $path")
            true
        } else {
            Log.e(TAG, "Failed to load module '$name'")
            false
        }
    }
    
    /**
     * Unloads a module
     */
    suspend fun unloadModule(name: String): Boolean = withContext(Dispatchers.IO) {
        if (managerPtr == 0L) return@withContext false
        
        val result = multi_manager_unload_index(managerPtr, name)
        if (result == 0) {
            loadedModules.remove(name)
            true
        } else {
            false
        }
    }
    
    /**
     * Triggers a reload for a specific module
     */
    suspend fun reloadModule(name: String): Boolean = withContext(Dispatchers.IO) {
        if (managerPtr == 0L) return@withContext false
        
        multi_manager_reload_index(managerPtr, name) == 0
    }
    
    // MARK: - Search
    
    /**
     * The primary search function
     */
    suspend fun search(
        query: String, 
        config: SearchConfig = SearchConfig()
    ): List<SearchResult> = withContext(Dispatchers.IO) {
        if (managerPtr == 0L) return@withContext emptyList()
        
        try {
            // Serialize config to JSON
            val configJson = json.encodeToString(config)
            
            // Perform search
            val resultJson = multi_manager_search(managerPtr, query, configJson)
                ?: return@withContext emptyList()
            
            // Note: JNI automatically handles string memory management
            // No need to call free_rust_string for JNI strings
            
            // Decode results
            json.decodeFromString<List<SearchResult>>(resultJson)
        } catch (e: Exception) {
            Log.e(TAG, "Search error", e)
            emptyList()
        }
    }
    
    // MARK: - Statistics
    
    /**
     * Gets statistics for all loaded modules
     */
    suspend fun getModuleStats(): List<ModuleStats> = withContext(Dispatchers.IO) {
        if (managerPtr == 0L) return@withContext emptyList()
        
        try {
            val resultJson = multi_manager_get_stats(managerPtr)
                ?: return@withContext emptyList()
            
            json.decodeFromString<List<ModuleStats>>(resultJson)
        } catch (e: Exception) {
            Log.e(TAG, "Stats error", e)
            emptyList()
        }
    }
    
    // MARK: - Helpers
    
    /**
     * Pre-warm the search engine with a dummy query
     */
    suspend fun prewarmSearch() = withContext(Dispatchers.IO) {
        try {
            val config = SearchConfig(limit = 1)
            search("the", config)
            Log.d(TAG, "Pre-warm completed")
        } catch (e: Exception) {
            Log.e(TAG, "Pre-warm failed", e)
        }
    }
    
    /**
     * Get loaded module names
     */
    fun getLoadedModules(): Set<String> = loadedModules.toSet()
}