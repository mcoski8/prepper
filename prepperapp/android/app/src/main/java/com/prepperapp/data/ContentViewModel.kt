package com.prepperapp.data

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.viewModelScope
import com.google.gson.Gson
import com.prepperapp.data.db.ContentDatabase
import com.prepperapp.data.repository.ContentRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

class ContentViewModel(application: Application) : AndroidViewModel(application) {
    
    enum class ContentStatus {
        LOADING,
        READY,
        ERROR
    }
    
    data class ContentManifest(
        val version: String,
        val type: String,
        val name: String,
        val description: String,
        val size_mb: Double,
        val requires_external_storage: Boolean,
        val content: ContentInfo
    )
    
    data class ContentInfo(
        val databases: List<String>,
        val categories: List<String>,
        val article_count: Int,
        val priority_levels: List<Int>,
        val features: ContentFeatures
    )
    
    data class ContentFeatures(
        val offline_maps: Boolean,
        val plant_identification: Boolean,
        val pill_identification: Boolean,
        val medical_procedures: Boolean,
        val survival_basics: Boolean,
        val emergency_signaling: Boolean
    )
    
    private val contentRepository = ContentRepository(application)
    
    private val _contentStatus = MutableLiveData<ContentStatus>()
    val contentStatus: LiveData<ContentStatus> = _contentStatus
    
    private val _contentManifest = MutableLiveData<ContentManifest>()
    val contentManifest: LiveData<ContentManifest> = _contentManifest
    
    private val _availableCategories = MutableLiveData<List<String>>()
    val availableCategories: LiveData<List<String>> = _availableCategories
    
    private val _searchResults = MutableLiveData<List<Article>>()
    val searchResults: LiveData<List<Article>> = _searchResults
    
    fun initializeContent() {
        viewModelScope.launch {
            _contentStatus.value = ContentStatus.LOADING
            
            try {
                // Discover available content
                val manifest = discoverContent()
                if (manifest != null) {
                    _contentManifest.value = manifest
                    _availableCategories.value = manifest.content.categories
                    
                    // Initialize database
                    contentRepository.initialize(manifest)
                    
                    _contentStatus.value = ContentStatus.READY
                } else {
                    // No content found, use fallback
                    loadFallbackContent()
                }
            } catch (e: Exception) {
                e.printStackTrace()
                _contentStatus.value = ContentStatus.ERROR
                loadFallbackContent()
            }
        }
    }
    
    private suspend fun discoverContent(): ContentManifest? = withContext(Dispatchers.IO) {
        val contentLocations = listOf(
            // Internal app storage
            File(getApplication<Application>().filesDir, "content"),
            // App's external files directory
            File(getApplication<Application>().getExternalFilesDir(null), "content"),
            // Shared external storage (requires permission)
            File("/storage/emulated/0/PrepperApp/content"),
            // SD card locations (device-specific)
            File("/storage/sdcard1/PrepperApp/content"),
            // USB storage (device-specific)
            File("/mnt/usb/PrepperApp/content")
        )
        
        for (location in contentLocations) {
            val manifestFile = File(location, "content_manifest.json")
            if (manifestFile.exists() && manifestFile.canRead()) {
                try {
                    val json = manifestFile.readText()
                    return Gson().fromJson(json, ContentManifest::class.java)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
        
        // Check assets for bundled test content
        try {
            val assetManager = getApplication<Application>().assets
            val manifestStream = assetManager.open("content/content_manifest.json")
            val json = manifestStream.bufferedReader().use { it.readText() }
            return Gson().fromJson(json, ContentManifest::class.java)
        } catch (e: Exception) {
            // No bundled content
        }
        
        return null
    }
    
    private fun loadFallbackContent() {
        // Create minimal fallback manifest
        val fallbackManifest = ContentManifest(
            version = "1.0",
            type = "fallback",
            name = "Emergency Basics",
            description = "Minimal emergency content",
            size_mb = 0.1,
            requires_external_storage = false,
            content = ContentInfo(
                databases = listOf("fallback.db"),
                categories = listOf("medical", "water", "shelter"),
                article_count = 10,
                priority_levels = listOf(0),
                features = ContentFeatures(
                    offline_maps = false,
                    plant_identification = false,
                    pill_identification = false,
                    medical_procedures = true,
                    survival_basics = true,
                    emergency_signaling = false
                )
            )
        )
        
        _contentManifest.value = fallbackManifest
        _availableCategories.value = fallbackManifest.content.categories
        _contentStatus.value = ContentStatus.ERROR
    }
    
    fun search(query: String) {
        viewModelScope.launch {
            try {
                val results = contentRepository.search(query)
                _searchResults.value = results
            } catch (e: Exception) {
                e.printStackTrace()
                _searchResults.value = emptyList()
            }
        }
    }
    
    fun getArticlesByPriority(priority: Int): LiveData<List<Article>> {
        return contentRepository.getArticlesByPriority(priority)
    }
    
    fun getArticlesByCategory(category: String): LiveData<List<Article>> {
        return contentRepository.getArticlesByCategory(category)
    }
    
    fun getArticle(id: String): LiveData<Article?> {
        return contentRepository.getArticle(id)
    }
}

// Data classes for articles
data class Article(
    val id: String,
    val title: String,
    val content: String,
    val category: String,
    val priority: Int,
    val time_critical: String?,
    val search_text: String?
)