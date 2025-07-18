package com.prepperapp

import android.graphics.Color
import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.prepperapp.databinding.ItemSearchResultBinding

data class SearchResult(
    val id: String,
    val title: String,
    val category: String,
    val summary: String,
    val priority: Int,
    val score: Float
)

class SearchResultAdapter(
    private val onItemClick: (SearchResult) -> Unit
) : ListAdapter<SearchResult, SearchResultAdapter.ViewHolder>(SearchResultDiffCallback()) {
    
    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val binding = ItemSearchResultBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return ViewHolder(binding, onItemClick)
    }
    
    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(getItem(position))
    }
    
    class ViewHolder(
        private val binding: ItemSearchResultBinding,
        private val onItemClick: (SearchResult) -> Unit
    ) : RecyclerView.ViewHolder(binding.root) {
        
        fun bind(result: SearchResult) {
            binding.titleText.text = result.title
            binding.categoryText.text = result.category.uppercase()
            binding.summaryText.text = result.summary
            
            // Set priority indicator color
            val priorityColor = when (result.priority) {
                5 -> Color.parseColor("#FF3838") // Red
                4 -> Color.parseColor("#FF9500") // Orange  
                3 -> Color.parseColor("#FFEB3B") // Yellow
                else -> Color.parseColor("#4D4D4D") // Gray
            }
            binding.priorityIndicator.setBackgroundColor(priorityColor)
            
            // Click listener
            binding.root.setOnClickListener {
                onItemClick(result)
            }
        }
    }
    
    class SearchResultDiffCallback : DiffUtil.ItemCallback<SearchResult>() {
        override fun areItemsTheSame(oldItem: SearchResult, newItem: SearchResult): Boolean {
            return oldItem.id == newItem.id
        }
        
        override fun areContentsTheSame(oldItem: SearchResult, newItem: SearchResult): Boolean {
            return oldItem == newItem
        }
    }
}