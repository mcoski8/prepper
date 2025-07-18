use anyhow::Result;
use clap::Parser;
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use tantivy::schema::{Schema, TEXT, STORED, STRING, FAST};
use tantivy::{doc, Index, IndexWriter};
use tantivy::store::Compressor;

// Define the structure of an article from the JSONL file
#[derive(serde::Deserialize)]
struct Article {
    id: String,
    title: String,
    summary: String,
    content: String, // The full, cleaned content for indexing
    priority: u8,
    keywords: Vec<String>,
}

// Define command-line arguments
#[derive(Parser, Debug)]
#[command(author, version, about = "Tantivy indexer for PrepperApp", long_about = None)]
struct Args {
    /// Path to the Tantivy index directory
    #[arg(short, long)]
    index: PathBuf,

    /// Path to the input JSONL file
    #[arg(short, long)]
    input: PathBuf,

    /// Number of threads for indexing (default: 4)
    #[arg(short, long, default_value = "4")]
    threads: usize,

    /// Index writer heap size in MB (default: 500)
    #[arg(short = 'm', long, default_value = "500")]
    heap_size: usize,
}

fn main() -> Result<()> {
    let args = Args::parse();

    // Configure Rayon's thread pool
    rayon::ThreadPoolBuilder::new()
        .num_threads(args.threads)
        .thread_name(|idx| format!("tantivy-indexer-{}", idx))
        .build_global()?;

    println!("Starting Tantivy indexer...");
    println!("Input: {}", args.input.display());
    println!("Index: {}", args.index.display());
    println!("Threads: {}", args.threads);
    println!("Heap size: {}MB", args.heap_size);

    // 1. Define the schema (consistent with mobile searcher)
    let mut schema_builder = Schema::builder();
    
    // ID field - stored and indexed as a string
    let id_field = schema_builder.add_text_field("id", STRING | STORED);
    
    // Title field - indexed and stored with compression
    let title_field = schema_builder.add_text_field("title", TEXT | STORED);
    
    // Summary field - indexed and stored with compression
    let summary_field = schema_builder.add_text_field("summary", TEXT | STORED);
    
    // Content field - indexed only, NOT stored to save space
    let content_field = schema_builder.add_text_field("content", TEXT);
    
    // Priority field - stored as u64, also add as FAST field for quick filtering
    let priority_field = schema_builder.add_u64_field("priority", STORED | FAST);
    
    // Module field - which content module this belongs to
    let module_field = schema_builder.add_text_field("module", STRING | STORED);
    
    let schema = schema_builder.build();

    // 2. Open or create the index
    let index = match Index::open_in_dir(&args.index) {
        Ok(existing_index) => {
            println!("Opening existing index...");
            // Verify schema matches
            if existing_index.schema() != schema {
                anyhow::bail!("Schema mismatch! Existing index has different schema.");
            }
            existing_index
        }
        Err(_) => {
            println!("Creating new index...");
            std::fs::create_dir_all(&args.index)?;
            Index::create_in_dir(&args.index, schema.clone())?
        }
    };

    // 3. Create an index writer with configuration
    let heap_size_bytes = args.heap_size * 1_000_000;
    let mut index_writer: IndexWriter = index.writer_with_num_threads(args.threads, heap_size_bytes)?;

    // 4. Read the JSONL file and add documents
    let file = File::open(&args.input)?;
    let reader = BufReader::new(file);

    let mut doc_count = 0;
    let mut error_count = 0;

    for (line_num, line) in reader.lines().enumerate() {
        match line {
            Ok(line_content) => {
                match serde_json::from_str::<Article>(&line_content) {
                    Ok(article) => {
                        // Create Tantivy document
                        let mut doc = doc!(
                            id_field => article.id.clone(),
                            title_field => article.title,
                            summary_field => article.summary,
                            content_field => article.content,
                            priority_field => article.priority as u64,
                            module_field => "core" // Default to "core" module
                        );

                        // Add the document
                        index_writer.add_document(doc)?;
                        doc_count += 1;

                        // Progress reporting
                        if doc_count % 100 == 0 {
                            print!("\rProcessed {} documents...", doc_count);
                            use std::io::Write;
                            std::io::stdout().flush()?;
                        }
                    }
                    Err(e) => {
                        eprintln!("\nError parsing JSON at line {}: {}", line_num + 1, e);
                        error_count += 1;
                    }
                }
            }
            Err(e) => {
                eprintln!("\nError reading line {}: {}", line_num + 1, e);
                error_count += 1;
            }
        }
    }

    println!("\n\nFinished reading. Processed {} documents with {} errors.", doc_count, error_count);

    // 5. Commit changes
    println!("Committing to index (this may take a moment)...");
    let commit_start = std::time::Instant::now();
    
    index_writer.commit()?;
    
    let commit_duration = commit_start.elapsed();
    println!("Commit completed in {:.2}s", commit_duration.as_secs_f64());

    // 6. Report final statistics
    let index_reader = index.reader()?;
    let searcher = index_reader.searcher();
    println!("\n=== Index Statistics ===");
    println!("Total documents in index: {}", searcher.num_docs());
    
    // Calculate approximate index size
    let index_size: u64 = std::fs::read_dir(&args.index)?
        .filter_map(|entry| entry.ok())
        .filter_map(|entry| entry.metadata().ok())
        .map(|metadata| metadata.len())
        .sum();
    
    println!("Index size on disk: {:.2} MB", index_size as f64 / 1_048_576.0);
    println!("Average size per document: {:.2} KB", (index_size as f64 / searcher.num_docs() as f64) / 1024.0);

    println!("\nIndexing completed successfully!");

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::TempDir;

    #[test]
    fn test_indexing_single_document() -> Result<()> {
        // Create temporary directories
        let temp_dir = TempDir::new()?;
        let index_path = temp_dir.path().join("test_index");
        let input_file = temp_dir.path().join("test_input.jsonl");

        // Write test data
        let test_article = Article {
            id: "test_001".to_string(),
            title: "Hemorrhage Control".to_string(),
            summary: "Critical steps for controlling severe bleeding".to_string(),
            content: "Apply direct pressure to the wound...".to_string(),
            priority: 0,
            keywords: vec!["bleeding".to_string(), "emergency".to_string()],
        };

        let mut file = File::create(&input_file)?;
        writeln!(file, "{}", serde_json::to_string(&test_article)?)?;

        // Run indexer
        let args = Args {
            index: index_path.clone(),
            input: input_file,
            threads: 1,
            heap_size: 50,
        };

        // Would need to refactor main logic into a separate function to test
        // For now, this test shows the structure

        Ok(())
    }
}