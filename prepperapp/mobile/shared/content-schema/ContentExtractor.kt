package com.prepperapp.content

import android.content.Context
import android.os.StatFs
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.*
import java.util.zip.ZipInputStream

/**
 * Manages the extraction of the PrepperApp content bundle
 * with atomic, resumable operations
 */
class ContentExtractor(private val context: Context) {
    
    sealed class ExtractionState {
        object NotStarted : ExtractionState()
        data class InProgress(val progress: Float) : ExtractionState()
        object Completed : ExtractionState()
        data class Failed(val error: Throwable) : ExtractionState()
    }
    
    sealed class ExtractionError : Exception() {
        data class InsufficientStorage(
            val required: Long,
            val available: Long
        ) : ExtractionError()
        object BundleNotFound : ExtractionError()
        data class ExtractionFailed(val cause: Throwable) : ExtractionError()
        object VerificationFailed : ExtractionError()
    }
    
    companion object {
        private const val BUNDLE_NAME = "prepperapp-p0-v1.0.0"
        private const val REQUIRED_SPACE = 300L * 1024 * 1024 // 300MB safety margin
        private const val EXTRACTION_FLAG = ".extraction_complete"
    }
    
    private val _state = MutableStateFlow<ExtractionState>(ExtractionState.NotStarted)
    val state: StateFlow<ExtractionState> = _state
    
    private var extractionJob: Job? = null
    
    /**
     * Check if content is already extracted and valid
     */
    fun isContentReady(): Boolean {
        val contentDir = File(context.filesDir, BUNDLE_NAME)
        val flagFile = File(contentDir, EXTRACTION_FLAG)
        return flagFile.exists()
    }
    
    /**
     * Start or resume content extraction
     */
    suspend fun startExtraction() = coroutineScope {
        // Cancel any existing extraction
        extractionJob?.cancel()
        
        // Check if already completed
        if (isContentReady()) {
            _state.value = ExtractionState.Completed
            return@coroutineScope
        }
        
        // Check available storage
        val available = getAvailableStorage()
        if (available < REQUIRED_SPACE) {
            val error = ExtractionError.InsufficientStorage(
                required = REQUIRED_SPACE,
                available = available
            )
            _state.value = ExtractionState.Failed(error)
            throw error
        }
        
        // Start extraction job
        extractionJob = launch(Dispatchers.IO) {
            try {
                performExtraction()
                _state.value = ExtractionState.Completed
            } catch (e: Exception) {
                _state.value = ExtractionState.Failed(e)
                throw e
            }
        }
        
        extractionJob?.join()
    }
    
    private suspend fun performExtraction() = withContext(Dispatchers.IO) {
        val tempDir = File(context.filesDir, "$BUNDLE_NAME.tmp")
        val finalDir = File(context.filesDir, BUNDLE_NAME)
        
        // Clean up any previous incomplete extraction
        tempDir.deleteRecursively()
        
        // Create temp directory
        tempDir.mkdirs()
        
        try {
            // Extract to temp directory with progress tracking
            extractBundle(
                to = tempDir,
                progressCallback = { progress ->
                    _state.value = ExtractionState.InProgress(progress)
                }
            )
            
            // Verify extraction
            verifyExtraction(tempDir)
            
            // Create completion flag
            File(tempDir, EXTRACTION_FLAG).createNewFile()
            
            // Atomic move to final location
            finalDir.deleteRecursively()
            if (!tempDir.renameTo(finalDir)) {
                throw ExtractionError.ExtractionFailed(
                    IOException("Failed to move extracted content")
                )
            }
        } catch (e: Exception) {
            tempDir.deleteRecursively()
            throw e
        }
    }
    
    private suspend fun extractBundle(
        to: File,
        progressCallback: suspend (Float) -> Unit
    ) = withContext(Dispatchers.IO) {
        val assetManager = context.assets
        
        try {
            // Open bundle from assets
            val bundleStream = assetManager.open("$BUNDLE_NAME.zip")
            val totalSize = bundleStream.available().toLong()
            var extractedSize = 0L
            
            ZipInputStream(BufferedInputStream(bundleStream)).use { zipIn ->
                var entry = zipIn.nextEntry
                
                while (entry != null) {
                    val entryFile = File(to, entry.name)
                    
                    if (entry.isDirectory) {
                        entryFile.mkdirs()
                    } else {
                        entryFile.parentFile?.mkdirs()
                        
                        FileOutputStream(entryFile).use { out ->
                            val buffer = ByteArray(8192)
                            var len: Int
                            
                            while (zipIn.read(buffer).also { len = it } > 0) {
                                out.write(buffer, 0, len)
                                extractedSize += len
                                
                                // Update progress
                                val progress = extractedSize.toFloat() / totalSize
                                progressCallback(progress.coerceIn(0f, 1f))
                                
                                // Check for cancellation
                                ensureActive()
                            }
                        }
                    }
                    
                    zipIn.closeEntry()
                    entry = zipIn.nextEntry
                }
            }
        } catch (e: IOException) {
            throw ExtractionError.ExtractionFailed(e)
        }
    }
    
    private fun verifyExtraction(dir: File) {
        // Verify required files exist
        val requiredFiles = listOf(
            "content/medical.db",
            "index/meta.json",
            "metadata/manifest.json"
        )
        
        for (file in requiredFiles) {
            if (!File(dir, file).exists()) {
                throw ExtractionError.VerificationFailed
            }
        }
        
        // Verify SQLite database is valid
        val dbFile = File(dir, "content/medical.db")
        // TODO: Open SQLite and run simple query to verify
    }
    
    private fun getAvailableStorage(): Long {
        val stat = StatFs(context.filesDir.path)
        return stat.availableBlocksLong * stat.blockSizeLong
    }
    
    /**
     * Clean up extracted content (for debugging/testing)
     */
    fun cleanupContent() {
        extractionJob?.cancel()
        File(context.filesDir, BUNDLE_NAME).deleteRecursively()
        File(context.filesDir, "$BUNDLE_NAME.tmp").deleteRecursively()
        _state.value = ExtractionState.NotStarted
    }
}