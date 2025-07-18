use anyhow::Result;
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::Path;
use tantivy::schema::*;
use tantivy::{doc, Index, IndexWriter, DateTime};

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    
    if args.len() != 2 {
        eprintln!("Usage: {} <jsonl_file>", args[0]);
        std::process::exit(1);
    }
    
    let jsonl_path = &args[1];
    
    println!("PrepperApp Index Builder");
    println!("========================\n");
    
    // Create index
    let index_path = "content_index";
    println!("Creating index at: {}", index_path);
    
    std::fs::create_dir_all(index_path)?;
    let schema = create_schema();
    let index = Index::create_in_dir(index_path, schema.clone())?;
    
    // Get field handles
    let id_field = schema.get_field("id").unwrap();
    let title_field = schema.get_field("title").unwrap();
    let category_field = schema.get_field("category").unwrap();
    let priority_field = schema.get_field("priority").unwrap();
    let summary_field = schema.get_field("summary").unwrap();
    let body_field = schema.get_field("body").unwrap();
    let medical_terms_field = schema.get_field("medical_terms").unwrap();
    let last_modified_field = schema.get_field("last_modified").unwrap();
    
    // Open writer
    let mut index_writer: IndexWriter = index.writer(100_000_000)?; // 100MB buffer
    
    // Read and index articles
    println!("Reading articles from: {}", jsonl_path);
    let file = File::open(jsonl_path)?;
    let reader = BufReader::new(file);
    
    let mut count = 0;
    let mut errors = 0;
    
    for line in reader.lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        
        match serde_json::from_str::<serde_json::Value>(&line) {
            Ok(article_json) => {
                // Extract fields
                let id = article_json["id"].as_str().unwrap_or("unknown");
                let title = article_json["title"].as_str().unwrap_or("Untitled");
                let category = article_json["category"].as_str().unwrap_or("general");
                let priority = article_json["priority"].as_u64().unwrap_or(2);
                let summary = article_json["summary"].as_str().unwrap_or("");
                let content = article_json["content"].as_str().unwrap_or("");
                
                // Extract medical terms from content for specialized indexing
                let medical_terms = extract_medical_terms(&title, &content);
                
                // Use current timestamp for last_modified
                let last_modified = DateTime::now();
                
                // Create document - note: content goes to "body" field and is NOT stored
                let doc = doc!(
                    id_field => id,
                    title_field => title,
                    category_field => category,
                    priority_field => priority,
                    summary_field => summary,
                    body_field => content,  // Indexed but not stored
                    medical_terms_field => medical_terms,
                    last_modified_field => last_modified
                );
                
                index_writer.add_document(doc)?;
                count += 1;
                
                if count % 100 == 0 {
                    println!("  Indexed {} articles...", count);
                }
            }
            Err(e) => {
                eprintln!("Error parsing article: {}", e);
                errors += 1;
            }
        }
    }
    
    // Commit changes
    println!("\nCommitting index...");
    index_writer.commit()?;
    
    println!("\n✅ Indexing complete!");
    println!("  Articles indexed: {}", count);
    if errors > 0 {
        println!("  Errors: {}", errors);
    }
    
    // Test the index
    println!("\nTesting index with sample query...");
    test_search(&index)?;
    
    Ok(())
}

fn create_schema() -> Schema {
    let mut schema_builder = Schema::builder();
    
    // Optimized schema based on Gemini's recommendations
    schema_builder.add_text_field("id", STRING | STORED); // FAST not needed for ID
    schema_builder.add_text_field("title", TEXT | STORED); // FAST not needed for high-cardinality field
    schema_builder.add_text_field("category", STRING | STORED | FAST); // FAST for faceting
    schema_builder.add_u64_field("priority", INDEXED | STORED | FAST); // INDEXED for filtering, FAST for speed
    schema_builder.add_text_field("summary", TEXT | STORED); // Pre-generated 200 char summary
    schema_builder.add_text_field("body", TEXT); // Full text indexed but NOT stored
    schema_builder.add_text_field("medical_terms", TEXT); // Separate field for medical terminology
    schema_builder.add_date_field("last_modified", STORED); // For future versioning
    
    schema_builder.build()
}

fn extract_medical_terms(title: &str, content: &str) -> String {
    // Extract medical terminology that should be indexed without stemming
    // This is a simple implementation - could be enhanced with a medical dictionary
    let medical_keywords = vec![
        "hemorrhage", "tourniquet", "anaphylaxis", "epinephrine", "hypothermia",
        "hyperthermia", "dehydration", "fracture", "dislocation", "pneumothorax",
        "myocardial", "infarction", "hypoglycemia", "hyperglycemia", "antiseptic"
    ];
    
    let combined = format!("{} {}", title, content).to_lowercase();
    let mut found_terms = Vec::new();
    
    for term in medical_keywords {
        if combined.contains(term) {
            found_terms.push(term);
        }
    }
    
    found_terms.join(" ")
}

fn test_search(index: &Index) -> Result<()> {
    use tantivy::collector::TopDocs;
    use tantivy::query::QueryParser;
    use tantivy::IndexReader;
    
    let reader = index.reader()?;
    let searcher = reader.searcher();
    let schema = index.schema();
    
    let title_field = schema.get_field("title").unwrap();
    let summary_field = schema.get_field("summary").unwrap();
    let body_field = schema.get_field("body").unwrap();
    
    let query_parser = QueryParser::for_index(index, vec![title_field, summary_field, body_field]);
    
    // Test queries
    let test_queries = vec!["bleeding", "water", "shelter", "emergency"];
    
    for query_str in test_queries {
        let query = query_parser.parse_query(query_str)?;
        let top_docs = searcher.search(&query, &TopDocs::with_limit(3))?;
        
        println!("\nQuery '{}' returned {} results:", query_str, top_docs.len());
        
        for (score, doc_address) in top_docs {
            let doc = searcher.doc(doc_address)?;
            let title = doc.get_first(schema.get_field("title").unwrap())
                .and_then(|v| v.as_text())
                .unwrap_or("N/A");
            println!("  - {} (score: {:.2})", title, score);
        }
    }
    
    Ok(())
}