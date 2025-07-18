package com.prepperapp

import android.content.Intent
import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.prepperapp.databinding.ActivityMainBinding
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {
    
    private lateinit var binding: ActivityMainBinding
    private lateinit var searchAdapter: SearchResultAdapter
    private var searchJob: Job? = null
    
    companion object {
        init {
            System.loadLibrary("tantivy_mobile")
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enable edge-to-edge display
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // Force dark theme
        window.apply {
            addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
            statusBarColor = android.graphics.Color.BLACK
            navigationBarColor = android.graphics.Color.BLACK
        }
        
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        setupUI()
        setupSearch()
        initializeTantivy()
    }
    
    private fun setupUI() {
        // Configure toolbar
        setSupportActionBar(binding.toolbar)
        supportActionBar?.title = "PrepperApp"
        
        // Configure RecyclerView
        searchAdapter = SearchResultAdapter { result ->
            openArticleDetail(result)
        }
        
        binding.recyclerView.apply {
            layoutManager = LinearLayoutManager(this@MainActivity)
            adapter = searchAdapter
            setHasFixedSize(true)
        }
        
        // Show search field and focus
        binding.searchEditText.requestFocus()
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE)
        
        // Empty state
        updateEmptyState(true)
    }
    
    private fun setupSearch() {
        binding.searchEditText.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            
            override fun afterTextChanged(s: Editable?) {
                // Cancel previous search
                searchJob?.cancel()
                
                val query = s?.toString() ?: ""
                if (query.isEmpty()) {
                    searchAdapter.submitList(emptyList())
                    updateEmptyState(true)
                    return
                }
                
                // Debounce search by 300ms
                searchJob = lifecycleScope.launch {
                    delay(300)
                    performSearch(query)
                }
            }
        })
    }
    
    private fun initializeTantivy() {
        // Initialize Tantivy logging
        TantivyBridge.initLogging()
        
        // TODO: Check if index exists, create if needed
        // For now, we'll use mock data
    }
    
    private fun performSearch(query: String) {
        binding.progressBar.visibility = View.VISIBLE
        updateEmptyState(false)
        
        lifecycleScope.launch {
            try {
                // TODO: Use TantivyBridge.search()
                // Mock search for now
                delay(50) // Simulate search time
                
                val mockResults = if (query.contains("bleed", ignoreCase = true)) {
                    listOf(
                        SearchResult(
                            id = "med-001",
                            title = "Controlling Severe Bleeding",
                            category = "Medical",
                            summary = "Life-saving techniques to stop hemorrhaging",
                            priority = 5,
                            score = 0.95f
                        ),
                        SearchResult(
                            id = "med-002",
                            title = "Treating Shock from Blood Loss",
                            category = "Medical",
                            summary = "Managing shock in bleeding victims",
                            priority = 5,
                            score = 0.87f
                        )
                    )
                } else if (query.contains("water", ignoreCase = true)) {
                    listOf(
                        SearchResult(
                            id = "water-001",
                            title = "Water Purification Methods",
                            category = "Water",
                            summary = "Making water safe to drink in emergencies",
                            priority = 5,
                            score = 0.92f
                        )
                    )
                } else {
                    emptyList()
                }
                
                searchAdapter.submitList(mockResults)
                updateEmptyState(mockResults.isEmpty() && query.isNotEmpty())
                
            } catch (e: Exception) {
                // Handle search error
                e.printStackTrace()
            } finally {
                binding.progressBar.visibility = View.GONE
            }
        }
    }
    
    private fun updateEmptyState(show: Boolean) {
        binding.emptyStateText.visibility = if (show) View.VISIBLE else View.GONE
        binding.recyclerView.visibility = if (show) View.GONE else View.VISIBLE
    }
    
    private fun openArticleDetail(result: SearchResult) {
        val intent = Intent(this, ArticleDetailActivity::class.java).apply {
            putExtra("article_id", result.id)
            putExtra("article_title", result.title)
            putExtra("article_category", result.category)
        }
        startActivity(intent)
    }
}