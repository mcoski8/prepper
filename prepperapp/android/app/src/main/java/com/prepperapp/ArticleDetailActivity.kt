package com.prepperapp

import android.os.Bundle
import android.view.Menu
import android.view.MenuItem
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import com.prepperapp.databinding.ActivityArticleDetailBinding

class ArticleDetailActivity : AppCompatActivity() {
    
    private lateinit var binding: ActivityArticleDetailBinding
    private var articleId: String? = null
    private var isEmergencyMode = false
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enable edge-to-edge display
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        binding = ActivityArticleDetailBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        setupUI()
        loadArticle()
    }
    
    private fun setupUI() {
        setSupportActionBar(binding.toolbar)
        supportActionBar?.apply {
            setDisplayHomeAsUpEnabled(true)
            setDisplayShowHomeEnabled(true)
        }
        
        // Get article info from intent
        articleId = intent.getStringExtra("article_id")
        val title = intent.getStringExtra("article_title") ?: ""
        val category = intent.getStringExtra("article_category") ?: ""
        
        binding.toolbar.title = ""
        binding.titleText.text = title
        binding.categoryText.text = "$category - PRIORITY 5"
    }
    
    private fun loadArticle() {
        // TODO: Load from ZIM file using articleId
        // For now, show mock content
        
        val content = """
IMMEDIATE ACTION REQUIRED

1. APPLY DIRECT PRESSURE
• Use clean cloth or gauze
• Press firmly on wound  
• Do not remove cloth if blood soaks through
• Add more layers on top

2. ELEVATE IF POSSIBLE
• Raise injured area above heart level
• Continue applying pressure

3. PRESSURE POINTS
• Brachial artery (arm wounds): Inside upper arm
• Femoral artery (leg wounds): Groin area
• Press firmly against bone

4. TOURNIQUET - LAST RESORT
• Only if bleeding is life-threatening
• Apply 2-3 inches above wound
• Never on a joint
• Tighten until bleeding stops
• Write time on tourniquet
• NEVER loosen once applied

5. SEEK IMMEDIATE MEDICAL HELP
• Call emergency services
• Keep victim warm
• Monitor for shock

WARNING: Uncontrolled bleeding can lead to death in minutes. Act quickly and decisively.
        """.trimIndent()
        
        binding.contentText.text = content
    }
    
    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.article_menu, menu)
        return true
    }
    
    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            android.R.id.home -> {
                onBackPressed()
                true
            }
            R.id.action_emergency_mode -> {
                toggleEmergencyMode()
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }
    
    private fun toggleEmergencyMode() {
        if (!isEmergencyMode) {
            AlertDialog.Builder(this)
                .setTitle("Emergency Mode")
                .setMessage("This will optimize the display for emergency situations with larger text and essential info only.")
                .setPositiveButton("Enable") { _, _ ->
                    enableEmergencyMode()
                }
                .setNegativeButton("Cancel", null)
                .show()
        } else {
            disableEmergencyMode()
        }
    }
    
    private fun enableEmergencyMode() {
        isEmergencyMode = true
        
        // Increase text sizes
        binding.titleText.textSize = 28f
        binding.contentText.textSize = 20f
        
        // Hide non-essential elements
        binding.categoryText.visibility = android.view.View.GONE
        
        // Update menu icon
        invalidateOptionsMenu()
    }
    
    private fun disableEmergencyMode() {
        isEmergencyMode = false
        
        // Reset text sizes
        binding.titleText.textSize = 24f
        binding.contentText.textSize = 17f
        
        // Show all elements
        binding.categoryText.visibility = android.view.View.VISIBLE
        
        // Update menu icon
        invalidateOptionsMenu()
    }
}