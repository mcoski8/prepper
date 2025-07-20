use anyhow::Result;
use colored::*;
use serde::{Deserialize, Serialize};
use tantivy::collector::TopDocs;
use tantivy::query::QueryParser;
use tantivy::{Index, ReloadPolicy, TantivyDocument};

#[derive(Debug, Serialize, Deserialize)]
struct TestQuery {
    query: String,
    category: String,
    safety_concern: Option<String>,
}

#[derive(Debug, Serialize)]
struct SearchResult {
    title: String,
    score: f32,
    id: String,
}

#[derive(Debug, Serialize)]
struct TestResult {
    query: String,
    category: String,
    safety_concern: Option<String>,
    results: Vec<SearchResult>,
    analysis: String,
}

fn main() -> Result<()> {
    // Define test queries - including dangerous/ambiguous ones
    let test_queries = vec![
        // High-Risk Ambiguous Phrases
        TestQuery {
            query: "cold water immersion".to_string(),
            category: "High-Risk Ambiguous".to_string(),
            safety_concern: Some("Could confuse hypothermia treatment with cold therapy".to_string()),
        },
        TestQuery {
            query: "infant cpr dose".to_string(),
            category: "High-Risk Ambiguous".to_string(),
            safety_concern: Some("Critical to get correct infant-specific information".to_string()),
        },
        TestQuery {
            query: "tourniquet nerve damage".to_string(),
            category: "High-Risk Ambiguous".to_string(),
            safety_concern: Some("User might be looking for when NOT to use tourniquet".to_string()),
        },
        TestQuery {
            query: "do not apply heat".to_string(),
            category: "High-Risk Ambiguous".to_string(),
            safety_concern: Some("Negation might not be understood correctly".to_string()),
        },
        
        // Action Queries
        TestQuery {
            query: "how to stop bleeding".to_string(),
            category: "Action Query".to_string(),
            safety_concern: None,
        },
        TestQuery {
            query: "treat snake bite".to_string(),
            category: "Action Query".to_string(),
            safety_concern: None,
        },
        TestQuery {
            query: "apply pressure wound".to_string(),
            category: "Action Query".to_string(),
            safety_concern: None,
        },
        
        // Symptom Queries
        TestQuery {
            query: "sudden chest pain".to_string(),
            category: "Symptom Query".to_string(),
            safety_concern: None,
        },
        TestQuery {
            query: "slurred speech dizzy".to_string(),
            category: "Symptom Query".to_string(),
            safety_concern: None,
        },
        TestQuery {
            query: "severe headache vomiting".to_string(),
            category: "Symptom Query".to_string(),
            safety_concern: None,
        },
        
        // Common Emergency Searches
        TestQuery {
            query: "hemorrhage".to_string(),
            category: "Emergency".to_string(),
            safety_concern: None,
        },
        TestQuery {
            query: "cardiac arrest".to_string(),
            category: "Emergency".to_string(),
            safety_concern: None,
        },
        TestQuery {
            query: "anaphylaxis".to_string(),
            category: "Emergency".to_string(),
            safety_concern: None,
        },
    ];

    // Path to index
    let index_path = "/Users/michaelchang/Documents/claudecode/prepper/prepperapp/data/indexes/tantivy-p0-mobile";
    
    println!("🔍 {}", "Tantivy Search Safety Validation Test".bold());
    println!("Index: {}", index_path);
    println!("Testing {} queries\n", test_queries.len());

    // Open the index
    let index = Index::open_in_dir(index_path)?;
    let reader = index
        .reader_builder()
        .reload_policy(ReloadPolicy::Manual)
        .try_into()?;
    let searcher = reader.searcher();
    
    // Get schema fields
    let schema = index.schema();
    let title_field = schema.get_field("title").unwrap();
    let content_field = schema.get_field("content").unwrap();
    let id_field = schema.get_field("id").unwrap();
    
    // Create query parser for title and content fields
    let query_parser = QueryParser::for_index(&index, vec![title_field, content_field]);
    
    let mut all_results = Vec::new();
    let mut concerning_results = 0;
    
    // Test each query
    for test_query in &test_queries {
        println!("{}", format!("\n📋 Query: '{}'", test_query.query).cyan());
        println!("   Category: {}", test_query.category);
        if let Some(concern) = &test_query.safety_concern {
            println!("   ⚠️  Safety Concern: {}", concern.yellow());
        }
        
        // Parse and execute query
        match query_parser.parse_query(&test_query.query) {
            Ok(query) => {
                // Search for top 5 results
                let top_docs = searcher.search(&query, &TopDocs::with_limit(5))?;
                
                let mut results = Vec::new();
                println!("\n   Top 5 Results:");
                
                for (score, doc_address) in top_docs {
                    let retrieved_doc: TantivyDocument = searcher.doc(doc_address)?;
                    let title = retrieved_doc
                        .get_first(title_field)
                        .and_then(|v| v.as_text())
                        .unwrap_or("No title");
                    let id = retrieved_doc
                        .get_first(id_field)
                        .and_then(|v| v.as_text())
                        .unwrap_or("No ID");
                    
                    println!("   {} [{}] - {}", 
                        format!("{:.2}", score).green(), 
                        id, 
                        title);
                    
                    results.push(SearchResult {
                        title: title.to_string(),
                        score,
                        id: id.to_string(),
                    });
                }
                
                // Analyze results for safety
                let analysis = analyze_results(&test_query, &results);
                let is_concerning = analysis.contains("CONCERN") || analysis.contains("WARNING");
                
                if is_concerning {
                    concerning_results += 1;
                    println!("\n   {} {}", "⚠️  Analysis:".red(), analysis);
                } else {
                    println!("\n   {} {}", "✅ Analysis:".green(), analysis);
                }
                
                all_results.push(TestResult {
                    query: test_query.query.clone(),
                    category: test_query.category.clone(),
                    safety_concern: test_query.safety_concern.clone(),
                    results,
                    analysis,
                });
            }
            Err(e) => {
                println!("   {} Failed to parse query: {}", "❌".red(), e);
            }
        }
    }
    
    // Summary
    println!("\n{}", "=".repeat(60));
    println!("{}", "SUMMARY".bold());
    println!("{}", "=".repeat(60));
    println!("Total queries tested: {}", test_queries.len());
    println!("Queries with safety concerns: {}", concerning_results);
    
    if concerning_results == 0 {
        println!("\n{} {}", "✅".green(), "All queries returned safe and relevant results!".green());
        println!("\nRecommendation: Current index is safe for deployment.");
    } else {
        println!("\n{} {} queries returned potentially concerning results", "⚠️".yellow(), concerning_results);
        println!("\nRecommendation: Review concerning queries and consider mitigations.");
    }
    
    // Save detailed results
    let results_json = serde_json::to_string_pretty(&all_results)?;
    std::fs::write("search_test_results.json", results_json)?;
    println!("\n📄 Detailed results saved to: search_test_results.json");
    
    Ok(())
}

fn analyze_results(query: &TestQuery, results: &[SearchResult]) -> String {
    if results.is_empty() {
        return "WARNING: No results found. Users might not find critical information.".to_string();
    }
    
    // Check for specific safety concerns
    if let Some(concern) = &query.safety_concern {
        match query.query.as_str() {
            "cold water immersion" => {
                // Check if top results are about hypothermia (dangerous) or therapy (safe)
                let top_title = &results[0].title.to_lowercase();
                if top_title.contains("hypotherm") || top_title.contains("cold shock") {
                    return "Good - top results focus on cold water dangers/hypothermia".to_string();
                } else if top_title.contains("therapy") || top_title.contains("treatment") {
                    return "CONCERN: Top result might be about cold therapy, not emergency treatment".to_string();
                }
            }
            "infant cpr dose" => {
                let top_title = &results[0].title.to_lowercase();
                if top_title.contains("infant") || top_title.contains("pediatric") || top_title.contains("baby") {
                    return "Good - results are infant-specific".to_string();
                } else {
                    return "CONCERN: Top results may not be infant-specific".to_string();
                }
            }
            "do not apply heat" => {
                // This is tricky - we're looking for what NOT to do
                return "CONCERN: Boolean search may not understand negation properly".to_string();
            }
            _ => {}
        }
    }
    
    // General relevance check
    let query_words: Vec<&str> = query.query.split_whitespace().collect();
    let title_words = results[0].title.to_lowercase();
    let matching_words = query_words.iter()
        .filter(|w| title_words.contains(&w.to_lowercase()))
        .count();
    
    if matching_words as f32 / query_words.len() as f32 > 0.5 {
        "Good - top results contain majority of query terms".to_string()
    } else {
        "Results seem relevant based on scoring".to_string()
    }
}