use anyhow::Result;
use clap::Parser;
use serde::{Deserialize, Serialize};
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use tantivy::collector::Count;
use tantivy::query::AllQuery;
use tantivy::schema::*;
use tantivy::{doc, Index, IndexWriter, ReloadPolicy};

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Path to the Tantivy index directory
    #[arg(short, long)]
    index: PathBuf,

    /// Path to the input JSONL file
    #[arg(short = 'i', long)]
    input: PathBuf,

    /// Number of threads for indexing
    #[arg(short, long, default_value = "2")]
    threads: usize,

    /// Heap size in MB for the index writer
    #[arg(short = 'H', long, default_value = "100")]
    heap_size: usize,

    /// Finalize the index after adding documents (merge to single segment)
    #[arg(short, long)]
    finalize: bool,
}

#[derive(Debug, Deserialize, Serialize)]
struct Article {
    id: String,
    title: String,
    summary: String,
    content: String,
    priority: u32,
    keywords: Vec<String>,
}

fn main() -> Result<()> {
    let args = Args::parse();

    // Set up thread pool for Tantivy
    rayon::ThreadPoolBuilder::new()
        .num_threads(args.threads)
        .thread_name(|idx| format!("tantivy-mobile-{}", idx))
        .build_global()?;

    println!("Starting Mobile-Optimized Tantivy indexer...");
    println!("Input: {}", args.input.display());
    println!("Index: {}", args.index.display());
    println!("Threads: {}", args.threads);
    println!("Heap size: {}MB", args.heap_size);

    // 1. Define MOBILE-OPTIMIZED schema
    let mut schema_builder = Schema::builder();
    
    // ID field - stored and indexed as a string
    let id_field = schema_builder.add_text_field("id", STRING | STORED);
    
    // Title field - stored ONLY (not indexed to save space)
    // We'll search in content field which includes title text
    let title_field = schema_builder.add_text_field("title", STORED);
    
    // Summary field - NOT stored, NOT indexed (save ~30% of index size)
    // Summary text is already in content field for searching
    
    // Content field - indexed with BASIC options (no positions/frequencies)
    // This saves ~40% of index size but disables phrase queries
    let text_options = TextOptions::default()
        .set_indexing_options(
            TextFieldIndexing::default()
                .set_tokenizer("default")
                .set_index_option(IndexRecordOption::Basic)
        );
    let content_field = schema_builder.add_text_field("content", text_options);
    
    // Priority field - stored as u64, also add as FAST field for quick filtering
    let priority_field = schema_builder.add_u64_field("priority", STORED | FAST);
    
    // Module field - which content module this belongs to
    let module_field = schema_builder.add_text_field("module", STRING | STORED);
    
    let schema = schema_builder.build();

    // 2. Create the index (always fresh for mobile optimization)
    println!("Creating mobile-optimized index...");
    std::fs::create_dir_all(&args.index)?;
    let index = Index::create_in_dir(&args.index, schema.clone())?;

    // 3. Create an index writer with smaller heap for mobile
    let heap_size_bytes = args.heap_size * 1_000_000;
    let mut index_writer: IndexWriter = index.writer_with_num_threads(1, heap_size_bytes)?;

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
                        // For mobile, combine title and summary into content for searching
                        let searchable_content = format!(
                            "{} {} {}", 
                            article.title, 
                            article.summary, 
                            article.content
                        );
                        
                        // Create minimal document
                        let doc = doc!(
                            id_field => article.id.clone(),
                            title_field => article.title,
                            content_field => searchable_content,
                            priority_field => article.priority as u64,
                            module_field => "core"
                        );

                        // Add the document
                        index_writer.add_document(doc)?;
                        doc_count += 1;

                        if doc_count % 100 == 0 {
                            print!("Processed {} documents...", doc_count);
                            // Flush to ensure progress is visible
                            use std::io::Write;
                            std::io::stdout().flush()?;
                            print!("\r"); // Return to start of line for next update
                        }
                    }
                    Err(e) => {
                        eprintln!("Error parsing JSON on line {}: {}", line_num + 1, e);
                        error_count += 1;
                    }
                }
            }
            Err(e) => {
                eprintln!("Error reading line {}: {}", line_num + 1, e);
                error_count += 1;
            }
        }
    }

    // Print final count
    println!("\nFinished reading. Processed {} documents with {} errors.", doc_count, error_count);

    // 5. Commit the documents
    println!("Committing to index (this may take a moment)...");
    let start = std::time::Instant::now();
    index_writer.commit()?;
    println!("Commit completed in {:.2}s", start.elapsed().as_secs_f32());

    // 6. Finalize the index if requested
    if args.finalize {
        println!("\nFinalizing index: merging segments...");
        let start = std::time::Instant::now();
        
        // Force merge to a single segment for optimal mobile performance
        let segment_ids: Vec<_> = {
            let index_reader = index.reader()?;
            let searcher = index_reader.searcher();
            searcher.segment_readers()
                .iter()
                .map(|segment_reader| segment_reader.segment_id())
                .collect()
        };
        
        println!("Found {} segments to merge", segment_ids.len());
        
        if segment_ids.len() > 1 {
            // Create a new writer for merging
            let mut merge_writer: IndexWriter = index.writer_with_num_threads(1, heap_size_bytes)?;
            
            // Merge all segments
            let merge_future = merge_writer.merge(&segment_ids);
            futures::executor::block_on(merge_future)?;
            
            // Garbage collect old files
            let gc_future = merge_writer.garbage_collect_files();
            futures::executor::block_on(gc_future)?;
            
            // Wait for merge to complete (this consumes the writer)
            merge_writer.wait_merging_threads()?;
            println!("✓ Segments merged and garbage collected.");
        } else {
            println!("✓ Index already has single segment.");
        }
        
        println!("Finalization completed in {:.2}s", start.elapsed().as_secs_f32());
    }

    // 7. Report final statistics
    let index_reader = index.reader_builder()
        .reload_policy(ReloadPolicy::Manual)
        .try_into()?;
    let searcher = index_reader.searcher();
    let all_docs_count = searcher.search(&AllQuery, &Count)?;
    
    // Calculate index size
    let index_size_bytes: u64 = std::fs::read_dir(&args.index)?
        .filter_map(|entry| entry.ok())
        .filter_map(|entry| entry.metadata().ok())
        .filter(|metadata| metadata.is_file())
        .map(|metadata| metadata.len())
        .sum();
    
    let index_size_mb = index_size_bytes as f64 / (1024.0 * 1024.0);
    let avg_size_kb = if all_docs_count > 0 {
        (index_size_bytes as f64 / all_docs_count as f64) / 1024.0
    } else {
        0.0
    };

    println!("\n=== Mobile Index Statistics ===");
    println!("Total documents in index: {}", all_docs_count);
    println!("Index size on disk: {:.2} MB", index_size_mb);
    println!("Average size per document: {:.2} KB", avg_size_kb);
    println!("\nMobile optimizations applied:");
    println!("- Basic index options (no positions/frequencies)");
    println!("- No indexed title field (search via content)");
    println!("- No stored summary field");
    println!("- Single segment (if finalized)");

    println!("\nIndexing completed successfully!");

    Ok(())
}