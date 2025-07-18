package com.prepperapp.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.ripple.rememberRipple
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.prepperapp.BuildConfig
import com.prepperapp.SearchResult

@Composable
fun SearchResultCard(
    result: SearchResult,
    onTap: () -> Unit,
    modifier: Modifier = Modifier
) {
    val haptic = LocalHapticFeedback.current
    
    // Map module to priority color
    val priorityColor = when (result.module) {
        "critical", "emergency" -> Color.Red
        "important", "core" -> Color.Yellow
        else -> Color.Gray
    }
    
    Card(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 100.dp) // Large tap target
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = rememberRipple(bounded = true, color = Color.White.copy(alpha = 0.1f))
            ) {
                haptic.performHapticFeedback(androidx.compose.ui.hapticfeedback.HapticFeedbackType.TextHandleMove)
                onTap()
            },
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color.Black.copy(alpha = 0.2f)
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 0.dp, top = 16.dp, end = 16.dp, bottom = 16.dp)
        ) {
            // Priority Indicator
            Box(
                modifier = Modifier
                    .width(8.dp)
                    .fillMaxHeight()
                    .background(priorityColor)
            )
            
            Spacer(modifier = Modifier.width(16.dp))
            
            // Content
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                // Title with large, bold font
                Text(
                    text = result.title,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                
                // Summary with good contrast
                Text(
                    text = result.summary,
                    fontSize = 16.sp,
                    color = Color.Gray,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis
                )
                
                // Module/Category indicator
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Surface(
                        shape = RoundedCornerShape(4.dp),
                        color = priorityColor.copy(alpha = 0.2f)
                    ) {
                        Text(
                            text = result.module.uppercase(),
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = priorityColor
                        )
                    }
                    
                    // Relevance score (debug only)
                    if (BuildConfig.DEBUG) {
                        Text(
                            text = String.format("%.2f", result.score),
                            fontSize = 11.sp,
                            color = Color.Gray.copy(alpha = 0.6f)
                        )
                    }
                }
            }
            
            Spacer(modifier = Modifier.width(8.dp))
            
            // Navigation hint
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = Color.Gray,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

@Composable
fun SearchResultsList(
    results: List<SearchResult>,
    onSelectResult: (SearchResult) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        modifier = modifier,
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(results, key = { it.doc_id }) { result ->
            SearchResultCard(
                result = result,
                onTap = { onSelectResult(result) }
            )
        }
    }
}

// MARK: - Preview

@Preview(showBackground = true, backgroundColor = 0xFF000000)
@Composable
fun SearchResultCardPreview() {
    val sampleResults = listOf(
        SearchResult(
            doc_id = "1",
            title = "Severe Bleeding Control",
            summary = "Apply direct pressure to the wound immediately. Use a tourniquet if bleeding cannot be controlled with direct pressure. Call emergency services...",
            score = 0.95f,
            module = "critical"
        ),
        SearchResult(
            doc_id = "2",
            title = "Hypothermia Treatment",
            summary = "Move to warm shelter. Remove wet clothing. Insulate the entire body. Give warm beverages if conscious. Seek medical attention...",
            score = 0.87f,
            module = "important"
        ),
        SearchResult(
            doc_id = "3",
            title = "Water Purification Methods",
            summary = "Boil water for at least 1 minute. Use water purification tablets. Filter through clean cloth and sand. UV sterilization in clear bottles...",
            score = 0.72f,
            module = "core"
        )
    )
    
    MaterialTheme {
        SearchResultsList(
            results = sampleResults,
            onSelectResult = { /* Preview */ }
        )
    }
}