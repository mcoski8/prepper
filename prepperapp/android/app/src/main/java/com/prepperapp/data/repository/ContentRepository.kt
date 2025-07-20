package com.prepperapp.data.repository

import android.app.Application
import android.database.sqlite.SQLiteDatabase
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import com.prepperapp.data.Article
import com.prepperapp.data.ContentViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

class ContentRepository(private val application: Application) {
    
    private var database: SQLiteDatabase? = null
    private val contentPath = File(application.filesDir, "content")
    
    suspend fun initialize(manifest: ContentViewModel.ContentManifest) = withContext(Dispatchers.IO) {
        // Close existing database if any
        database?.close()
        
        // Find and open the database
        val dbName = manifest.content.databases.firstOrNull() ?: "content.db"
        val dbFile = findDatabase(dbName)
        
        if (dbFile != null && dbFile.exists()) {
            database = SQLiteDatabase.openDatabase(
                dbFile.absolutePath,
                null,
                SQLiteDatabase.OPEN_READONLY
            )
        } else {
            // Try to copy from assets if available
            copyTestContentFromAssets()
        }
    }
    
    private fun findDatabase(dbName: String): File? {
        val locations = listOf(
            File(contentPath, dbName),
            File(application.getExternalFilesDir(null), "content/$dbName"),
            File("/storage/emulated/0/PrepperApp/content/$dbName"),
            // Check the processed folder from our test content
            File(application.filesDir.parentFile?.parentFile?.parentFile, 
                 "prepperapp/data/processed/test_content.db")
        )
        
        return locations.firstOrNull { it.exists() && it.canRead() }
    }
    
    private fun copyTestContentFromAssets() {
        try {
            // For development, copy test content from project
            val sourceFile = File(application.filesDir.parentFile?.parentFile?.parentFile,
                                 "prepperapp/data/processed/test_content.db")
            
            if (sourceFile.exists()) {
                contentPath.mkdirs()
                val destFile = File(contentPath, "test_content.db")
                sourceFile.copyTo(destFile, overwrite = true)
                
                database = SQLiteDatabase.openDatabase(
                    destFile.absolutePath,
                    null,
                    SQLiteDatabase.OPEN_READONLY
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
            // Create minimal in-memory database
            createFallbackDatabase()
        }
    }
    
    private fun createFallbackDatabase() {
        database = SQLiteDatabase.create(null)
        
        // Create minimal schema
        database?.execSQL("""
            CREATE TABLE articles (
                id INTEGER PRIMARY KEY,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                category TEXT NOT NULL,
                priority INTEGER NOT NULL,
                time_critical TEXT,
                search_text TEXT
            )
        """)
        
        // Insert minimal emergency content
        val emergencyContent = listOf(
            Triple("Stop Bleeding", "Apply direct pressure with cloth. Press HARD.", "medical"),
            Triple("CPR", "30 chest compressions, 2 breaths. Repeat.", "medical"),
            Triple("Choking", "5 back blows, 5 abdominal thrusts. Repeat.", "medical"),
            Triple("Water", "Boil 1 minute. Or 8 drops bleach per gallon.", "water"),
            Triple("Hypothermia", "Get dry. Insulate from ground. Small shelter.", "shelter")
        )
        
        emergencyContent.forEachIndexed { index, (title, content, category) ->
            database?.execSQL("""
                INSERT INTO articles (id, title, content, category, priority, search_text)
                VALUES (?, ?, ?, ?, 0, ?)
            """, arrayOf(index + 1, title, content, category, "$title $content".lowercase()))
        }
    }
    
    suspend fun search(query: String): List<Article> = withContext(Dispatchers.IO) {
        val articles = mutableListOf<Article>()
        
        database?.let { db ->
            val searchQuery = "%${query.lowercase()}%"
            val cursor = db.rawQuery("""
                SELECT id, title, content, category, priority, time_critical
                FROM articles
                WHERE search_text LIKE ?
                ORDER BY priority ASC, title ASC
                LIMIT 50
            """, arrayOf(searchQuery))
            
            cursor.use {
                while (it.moveToNext()) {
                    articles.add(Article(
                        id = it.getString(0),
                        title = it.getString(1),
                        content = it.getString(2),
                        category = it.getString(3),
                        priority = it.getInt(4),
                        time_critical = it.getString(5),
                        search_text = null
                    ))
                }
            }
        }
        
        return articles
    }
    
    fun getArticlesByPriority(priority: Int): LiveData<List<Article>> {
        val result = MutableLiveData<List<Article>>()
        
        database?.let { db ->
            val articles = mutableListOf<Article>()
            val cursor = db.rawQuery("""
                SELECT id, title, content, category, priority, time_critical
                FROM articles
                WHERE priority = ?
                ORDER BY title ASC
            """, arrayOf(priority.toString()))
            
            cursor.use {
                while (it.moveToNext()) {
                    articles.add(Article(
                        id = it.getString(0),
                        title = it.getString(1),
                        content = it.getString(2),
                        category = it.getString(3),
                        priority = it.getInt(4),
                        time_critical = it.getString(5),
                        search_text = null
                    ))
                }
            }
            
            result.value = articles
        } ?: run {
            result.value = emptyList()
        }
        
        return result
    }
    
    fun getArticlesByCategory(category: String): LiveData<List<Article>> {
        val result = MutableLiveData<List<Article>>()
        
        database?.let { db ->
            val articles = mutableListOf<Article>()
            val cursor = db.rawQuery("""
                SELECT id, title, content, category, priority, time_critical
                FROM articles
                WHERE category = ?
                ORDER BY priority ASC, title ASC
            """, arrayOf(category))
            
            cursor.use {
                while (it.moveToNext()) {
                    articles.add(Article(
                        id = it.getString(0),
                        title = it.getString(1),
                        content = it.getString(2),
                        category = it.getString(3),
                        priority = it.getInt(4),
                        time_critical = it.getString(5),
                        search_text = null
                    ))
                }
            }
            
            result.value = articles
        } ?: run {
            result.value = emptyList()
        }
        
        return result
    }
    
    fun getArticle(id: String): LiveData<Article?> {
        val result = MutableLiveData<Article?>()
        
        database?.let { db ->
            val cursor = db.rawQuery("""
                SELECT id, title, content, category, priority, time_critical
                FROM articles
                WHERE id = ?
                LIMIT 1
            """, arrayOf(id))
            
            cursor.use {
                if (it.moveToFirst()) {
                    result.value = Article(
                        id = it.getString(0),
                        title = it.getString(1),
                        content = it.getString(2),
                        category = it.getString(3),
                        priority = it.getInt(4),
                        time_critical = it.getString(5),
                        search_text = null
                    )
                } else {
                    result.value = null
                }
            }
        } ?: run {
            result.value = null
        }
        
        return result
    }
}