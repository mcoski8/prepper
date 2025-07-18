use anyhow::Result;
use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use std::path::Path;
use tantivy::collector::TopDocs;
use tantivy::query::QueryParser;
use tantivy::schema::*;
use tantivy::{doc, Document, Index, IndexReader, IndexWriter, ReloadPolicy};
use tokio::fs;

#[derive(Parser)]
#[command(name = "tantivy-poc")]
#[command(about = "PrepperApp Tantivy Search PoC", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Create a new index with schema
    CreateIndex {
        #[arg(short, long)]
        path: String,
    },
    /// Index sample survival articles
    IndexContent {
        #[arg(short, long)]
        index_path: String,
    },
    /// Search the index
    Search {
        #[arg(short, long)]
        index_path: String,
        #[arg(short, long)]
        query: String,
    },
    /// Test multi-index search
    MultiSearch {
        #[arg(short, long)]
        core_index: String,
        #[arg(short, long)]
        module_index: String,
        #[arg(short, long)]
        query: String,
    },
}

#[derive(Debug, Serialize, Deserialize)]
struct SurvivalArticle {
    id: String,
    title: String,
    category: String,
    priority: u64,  // 1-5, higher is more critical
    summary: String,
    content: String,
}

fn create_schema() -> Schema {
    let mut schema_builder = Schema::builder();
    
    // FAST fields for quick retrieval
    schema_builder.add_text_field("id", STORED | FAST);
    schema_builder.add_text_field("title", TEXT | STORED | FAST);
    
    // Category field for filtering (basic indexing)
    schema_builder.add_text_field("category", STRING | STORED | FAST);
    
    // Priority as u64 field for boosting
    schema_builder.add_u64_field("priority", STORED | FAST);
    
    // Summary for search results
    schema_builder.add_text_field("summary", TEXT | STORED);
    
    // Main content field with positions for phrase queries
    schema_builder.add_text_field("content", TEXT);
    
    schema_builder.build()
}

async fn create_index(index_path: &str) -> Result<()> {
    println!("Creating index at: {}", index_path);
    
    fs::create_dir_all(index_path).await?;
    let path = Path::new(index_path);
    
    let schema = create_schema();
    let index = Index::create_in_dir(path, schema)?;
    
    // Configure merge policy for mobile optimization
    let mut index_writer = index.writer(50_000_000)?; // 50MB buffer
    index_writer.commit()?;
    
    println!("Index created successfully with schema:");
    println!("- id (FAST, STORED)");
    println!("- title (TEXT, FAST, STORED)");
    println!("- category (STRING, FAST, STORED)");
    println!("- priority (U64, FAST, STORED)");
    println!("- summary (TEXT, STORED)");
    println!("- content (TEXT)");
    
    Ok(())
}

fn get_sample_articles() -> Vec<SurvivalArticle> {
    vec![
        SurvivalArticle {
            id: "med-001".to_string(),
            title: "Controlling Severe Bleeding".to_string(),
            category: "medical".to_string(),
            priority: 5,
            summary: "Life-saving techniques to stop hemorrhaging using tourniquets and pressure".to_string(),
            content: "Severe bleeding can lead to death in minutes. Apply direct pressure immediately. If bleeding doesn't stop, use a tourniquet above the wound. Write the time on the tourniquet. Never loosen once applied. Seek medical help immediately.".to_string(),
        },
        SurvivalArticle {
            id: "water-001".to_string(),
            title: "Water Purification Methods".to_string(),
            category: "water".to_string(),
            priority: 5,
            summary: "Essential methods to make water safe for drinking in emergencies".to_string(),
            content: "Boiling water for 1 minute kills most pathogens. At altitudes above 6,500 feet, boil for 3 minutes. Water purification tablets work in 30 minutes. UV light purifiers need clear water. Filter first, then purify.".to_string(),
        },
        SurvivalArticle {
            id: "shelter-001".to_string(),
            title: "Emergency Shelter in Cold Weather".to_string(),
            category: "shelter".to_string(),
            priority: 4,
            summary: "How to build emergency shelter to prevent hypothermia".to_string(),
            content: "Hypothermia kills in hours. Find windbreak immediately. Insulate from ground using branches, leaves. Build small shelter to conserve body heat. Never sleep directly on snow or cold ground.".to_string(),
        },
        SurvivalArticle {
            id: "med-002".to_string(),
            title: "Treating Shock".to_string(),
            category: "medical".to_string(),
            priority: 5,
            summary: "Recognizing and treating shock in emergency situations".to_string(),
            content: "Shock symptoms: pale skin, rapid pulse, shallow breathing. Lay person flat, elevate legs 12 inches unless head/spine injury suspected. Keep warm with blankets. Do not give fluids if unconscious.".to_string(),
        },
        SurvivalArticle {
            id: "poison-001".to_string(),
            title: "Identifying Poisonous Plants".to_string(),
            category: "plants".to_string(),
            priority: 3,
            summary: "Common poisonous plants to avoid when foraging".to_string(),
            content: "Never eat white or yellow berries. Avoid plants with milky sap, three-leaf patterns, or umbrella-shaped flower clusters. When in doubt, don't eat it. Test unknown plants on skin first, wait 15 minutes for reaction.".to_string(),
        },
    ]
}

async fn index_content(index_path: &str) -> Result<()> {
    println!("Indexing content to: {}", index_path);
    
    let path = Path::new(index_path);
    let index = Index::open_in_dir(path)?;
    let schema = index.schema();
    
    let id_field = schema.get_field("id").unwrap();
    let title_field = schema.get_field("title").unwrap();
    let category_field = schema.get_field("category").unwrap();
    let priority_field = schema.get_field("priority").unwrap();
    let summary_field = schema.get_field("summary").unwrap();
    let content_field = schema.get_field("content").unwrap();
    
    let mut index_writer = index.writer(50_000_000)?;
    
    let articles = get_sample_articles();
    let total = articles.len();
    
    for (i, article) in articles.iter().enumerate() {
        let doc = doc!(
            id_field => article.id.clone(),
            title_field => article.title.clone(),
            category_field => article.category.clone(),
            priority_field => article.priority,
            summary_field => article.summary.clone(),
            content_field => article.content.clone()
        );
        
        index_writer.add_document(doc)?;
        println!("Indexed {}/{}: {}", i + 1, total, article.title);
    }
    
    index_writer.commit()?;
    println!("\nSuccessfully indexed {} articles", total);
    
    Ok(())
}

async fn search_index(index_path: &str, query_str: &str) -> Result<()> {
    println!("Searching for: '{}' in {}", query_str, index_path);
    
    let path = Path::new(index_path);
    let index = Index::open_in_dir(path)?;
    let schema = index.schema();
    
    let title_field = schema.get_field("title").unwrap();
    let summary_field = schema.get_field("summary").unwrap();
    let content_field = schema.get_field("content").unwrap();
    
    let reader: IndexReader = index
        .reader_builder()
        .reload_policy(ReloadPolicy::OnCommit)
        .try_into()?;
    
    let searcher = reader.searcher();
    
    // Search across multiple fields
    let query_parser = QueryParser::for_index(&index, vec![title_field, summary_field, content_field]);
    let query = query_parser.parse_query(query_str)?;
    
    let start = std::time::Instant::now();
    let top_docs = searcher.search(&query, &TopDocs::with_limit(10))?;
    let search_time = start.elapsed();
    
    println!("\nFound {} results in {:?}:", top_docs.len(), search_time);
    println!("----------------------------------------");
    
    for (score, doc_address) in top_docs {
        let retrieved_doc = searcher.doc(doc_address)?;
        
        let id = retrieved_doc.get_first(schema.get_field("id").unwrap())
            .and_then(|v| v.as_text())
            .unwrap_or("N/A");
            
        let title = retrieved_doc.get_first(schema.get_field("title").unwrap())
            .and_then(|v| v.as_text())
            .unwrap_or("N/A");
            
        let category = retrieved_doc.get_first(schema.get_field("category").unwrap())
            .and_then(|v| v.as_text())
            .unwrap_or("N/A");
            
        let priority = retrieved_doc.get_first(schema.get_field("priority").unwrap())
            .and_then(|v| v.as_u64())
            .unwrap_or(0);
            
        let summary = retrieved_doc.get_first(schema.get_field("summary").unwrap())
            .and_then(|v| v.as_text())
            .unwrap_or("N/A");
        
        println!("Score: {:.2}", score);
        println!("ID: {} | Category: {} | Priority: {}", id, category, priority);
        println!("Title: {}", title);
        println!("Summary: {}", summary);
        println!("----------------------------------------");
    }
    
    Ok(())
}

async fn multi_search(core_index: &str, module_index: &str, query_str: &str) -> Result<()> {
    println!("Multi-index search for: '{}'", query_str);
    println!("Core index: {}", core_index);
    println!("Module index: {}", module_index);
    
    // Open both indexes
    let core_path = Path::new(core_index);
    let module_path = Path::new(module_index);
    
    let core_index = Index::open_in_dir(core_path)?;
    let module_index = Index::open_in_dir(module_path)?;
    
    // Create readers
    let core_reader: IndexReader = core_index
        .reader_builder()
        .reload_policy(ReloadPolicy::OnCommit)
        .try_into()?;
        
    let module_reader: IndexReader = module_index
        .reader_builder()
        .reload_policy(ReloadPolicy::OnCommit)
        .try_into()?;
    
    // Search both indexes
    println!("\n=== CORE INDEX RESULTS ===");
    search_single_index(&core_index, &core_reader, query_str).await?;
    
    println!("\n=== MODULE INDEX RESULTS ===");
    search_single_index(&module_index, &module_reader, query_str).await?;
    
    Ok(())
}

async fn search_single_index(index: &Index, reader: &IndexReader, query_str: &str) -> Result<()> {
    let schema = index.schema();
    let searcher = reader.searcher();
    
    let title_field = schema.get_field("title").unwrap();
    let summary_field = schema.get_field("summary").unwrap();
    let content_field = schema.get_field("content").unwrap();
    
    let query_parser = QueryParser::for_index(index, vec![title_field, summary_field, content_field]);
    let query = query_parser.parse_query(query_str)?;
    
    let start = std::time::Instant::now();
    let top_docs = searcher.search(&query, &TopDocs::with_limit(5))?;
    let search_time = start.elapsed();
    
    println!("Found {} results in {:?}", top_docs.len(), search_time);
    
    for (score, doc_address) in top_docs {
        let doc = searcher.doc(doc_address)?;
        let title = doc.get_first(schema.get_field("title").unwrap())
            .and_then(|v| v.as_text())
            .unwrap_or("N/A");
        println!("  - {} (score: {:.2})", title, score);
    }
    
    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    
    match cli.command {
        Commands::CreateIndex { path } => {
            create_index(&path).await?;
        }
        Commands::IndexContent { index_path } => {
            index_content(&index_path).await?;
        }
        Commands::Search { index_path, query } => {
            search_index(&index_path, &query).await?;
        }
        Commands::MultiSearch { core_index, module_index, query } => {
            multi_search(&core_index, &module_index, &query).await?;
        }
    }
    
    Ok(())
}