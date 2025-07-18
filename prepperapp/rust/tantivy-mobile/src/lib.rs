use libc::{c_char, c_void};
use serde::{Deserialize, Serialize};
use std::ffi::{CStr, CString};
use std::ptr;
use std::sync::{Arc, RwLock};
use tantivy::collector::TopDocs;
use tantivy::query::QueryParser;
use tantivy::schema::*;
use tantivy::{doc, Document, Index, IndexReader, IndexWriter, ReloadPolicy};

// Error codes
const SUCCESS: i32 = 0;
const ERROR_INVALID_PARAM: i32 = -1;
const ERROR_INDEX_CREATION: i32 = -2;
const ERROR_SEARCH_FAILED: i32 = -3;
const ERROR_INDEXING_FAILED: i32 = -4;

// Search result structure
#[repr(C)]
pub struct SearchResult {
    pub id: *mut c_char,
    pub title: *mut c_char,
    pub category: *mut c_char,
    pub summary: *mut c_char,
    pub priority: u64,
    pub score: f32,
}

#[repr(C)]
pub struct SearchResults {
    pub results: *mut SearchResult,
    pub count: usize,
    pub search_time_ms: u64,
}

// Index manager to hold references
pub struct IndexManager {
    index: Index,
    reader: Arc<RwLock<IndexReader>>,
    schema: Schema,
}

// Initialize logging for mobile platforms
#[no_mangle]
pub extern "C" fn tantivy_init_logging() {
    #[cfg(target_os = "android")]
    {
        android_logger::init_once(
            android_logger::Config::default()
                .with_max_level(log::LevelFilter::Info)
                .with_tag("TantivyMobile"),
        );
    }
    
    #[cfg(target_os = "ios")]
    {
        oslog::OsLogger::new("com.prepperapp.tantivy")
            .level_filter(log::LevelFilter::Info)
            .init()
            .ok();
    }
}

// Create a new index with PrepperApp schema
#[no_mangle]
pub extern "C" fn tantivy_create_index(path: *const c_char) -> *mut c_void {
    if path.is_null() {
        return ptr::null_mut();
    }

    let path_str = unsafe {
        match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        }
    };

    let schema = create_schema();
    
    let index = match std::fs::create_dir_all(path_str)
        .and_then(|_| Index::create_in_dir(path_str, schema.clone()).map_err(|e| e.into()))
    {
        Ok(idx) => idx,
        Err(_) => return ptr::null_mut(),
    };

    let reader = match index.reader_builder()
        .reload_policy(ReloadPolicy::OnCommit)
        .try_into()
    {
        Ok(r) => Arc::new(RwLock::new(r)),
        Err(_) => return ptr::null_mut(),
    };

    let manager = Box::new(IndexManager {
        index,
        reader,
        schema,
    });

    Box::into_raw(manager) as *mut c_void
}

// Open an existing index
#[no_mangle]
pub extern "C" fn tantivy_open_index(path: *const c_char) -> *mut c_void {
    if path.is_null() {
        return ptr::null_mut();
    }

    let path_str = unsafe {
        match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        }
    };

    let index = match Index::open_in_dir(path_str) {
        Ok(idx) => idx,
        Err(_) => return ptr::null_mut(),
    };

    let schema = index.schema();
    
    let reader = match index.reader_builder()
        .reload_policy(ReloadPolicy::OnCommit)
        .try_into()
    {
        Ok(r) => Arc::new(RwLock::new(r)),
        Err(_) => return ptr::null_mut(),
    };

    let manager = Box::new(IndexManager {
        index,
        reader,
        schema,
    });

    Box::into_raw(manager) as *mut c_void
}

// Add a document to the index
#[no_mangle]
pub extern "C" fn tantivy_add_document(
    index_ptr: *mut c_void,
    id: *const c_char,
    title: *const c_char,
    category: *const c_char,
    priority: u64,
    summary: *const c_char,
    content: *const c_char,
) -> i32 {
    if index_ptr.is_null() {
        return ERROR_INVALID_PARAM;
    }

    let manager = unsafe { &*(index_ptr as *const IndexManager) };

    // Convert C strings to Rust strings
    let id_str = unsafe { CStr::from_ptr(id).to_string_lossy().to_string() };
    let title_str = unsafe { CStr::from_ptr(title).to_string_lossy().to_string() };
    let category_str = unsafe { CStr::from_ptr(category).to_string_lossy().to_string() };
    let summary_str = unsafe { CStr::from_ptr(summary).to_string_lossy().to_string() };
    let content_str = unsafe { CStr::from_ptr(content).to_string_lossy().to_string() };

    // Get field handles
    let id_field = manager.schema.get_field("id").unwrap();
    let title_field = manager.schema.get_field("title").unwrap();
    let category_field = manager.schema.get_field("category").unwrap();
    let priority_field = manager.schema.get_field("priority").unwrap();
    let summary_field = manager.schema.get_field("summary").unwrap();
    let content_field = manager.schema.get_field("content").unwrap();

    // Create document
    let doc = doc!(
        id_field => id_str,
        title_field => title_str,
        category_field => category_str,
        priority_field => priority,
        summary_field => summary_str,
        content_field => content_str
    );

    // Add to index
    match manager.index.writer(50_000_000) {
        Ok(mut writer) => {
            if writer.add_document(doc).is_err() {
                return ERROR_INDEXING_FAILED;
            }
            SUCCESS
        }
        Err(_) => ERROR_INDEXING_FAILED,
    }
}

// Commit changes to the index
#[no_mangle]
pub extern "C" fn tantivy_commit(index_ptr: *mut c_void) -> i32 {
    if index_ptr.is_null() {
        return ERROR_INVALID_PARAM;
    }

    let manager = unsafe { &*(index_ptr as *const IndexManager) };

    match manager.index.writer(50_000_000) {
        Ok(mut writer) => {
            if writer.commit().is_err() {
                return ERROR_INDEXING_FAILED;
            }
            
            // Update the reader after commit
            if let Ok(new_reader) = manager.index.reader_builder()
                .reload_policy(ReloadPolicy::OnCommit)
                .try_into()
            {
                if let Ok(mut reader_guard) = manager.reader.write() {
                    *reader_guard = new_reader;
                }
            }
            
            SUCCESS
        }
        Err(_) => ERROR_INDEXING_FAILED,
    }
}

// Search the index
#[no_mangle]
pub extern "C" fn tantivy_search(
    index_ptr: *mut c_void,
    query: *const c_char,
    limit: usize,
) -> *mut SearchResults {
    if index_ptr.is_null() || query.is_null() {
        return ptr::null_mut();
    }

    let manager = unsafe { &*(index_ptr as *const IndexManager) };
    let query_str = unsafe { CStr::from_ptr(query).to_string_lossy() };

    let reader_guard = match manager.reader.read() {
        Ok(guard) => guard,
        Err(_) => return ptr::null_mut(),
    };
    
    let searcher = reader_guard.searcher();

    // Setup query parser for multiple fields
    let title_field = manager.schema.get_field("title").unwrap();
    let summary_field = manager.schema.get_field("summary").unwrap();
    let content_field = manager.schema.get_field("content").unwrap();

    let query_parser = QueryParser::for_index(
        &manager.index,
        vec![title_field, summary_field, content_field],
    );

    let query = match query_parser.parse_query(&query_str) {
        Ok(q) => q,
        Err(_) => return ptr::null_mut(),
    };

    // Perform search with timing
    let start = std::time::Instant::now();
    let top_docs = match searcher.search(&query, &TopDocs::with_limit(limit)) {
        Ok(docs) => docs,
        Err(_) => return ptr::null_mut(),
    };
    let search_time = start.elapsed();

    // Convert results to C-compatible format
    let mut results = Vec::new();
    
    for (score, doc_address) in top_docs {
        if let Ok(doc) = searcher.doc(doc_address) {
            let id = doc.get_first(manager.schema.get_field("id").unwrap())
                .and_then(|v| v.as_text())
                .unwrap_or("");
            let title = doc.get_first(manager.schema.get_field("title").unwrap())
                .and_then(|v| v.as_text())
                .unwrap_or("");
            let category = doc.get_first(manager.schema.get_field("category").unwrap())
                .and_then(|v| v.as_text())
                .unwrap_or("");
            let summary = doc.get_first(manager.schema.get_field("summary").unwrap())
                .and_then(|v| v.as_text())
                .unwrap_or("");
            let priority = doc.get_first(manager.schema.get_field("priority").unwrap())
                .and_then(|v| v.as_u64())
                .unwrap_or(0);

            results.push(SearchResult {
                id: CString::new(id).unwrap().into_raw(),
                title: CString::new(title).unwrap().into_raw(),
                category: CString::new(category).unwrap().into_raw(),
                summary: CString::new(summary).unwrap().into_raw(),
                priority,
                score,
            });
        }
    }

    let count = results.len();
    let results_ptr = results.as_mut_ptr();
    std::mem::forget(results);

    let search_results = Box::new(SearchResults {
        results: results_ptr,
        count,
        search_time_ms: search_time.as_millis() as u64,
    });

    Box::into_raw(search_results)
}

// Free search results
#[no_mangle]
pub extern "C" fn tantivy_free_search_results(results: *mut SearchResults) {
    if results.is_null() {
        return;
    }

    unsafe {
        let results_box = Box::from_raw(results);
        
        // Free individual result strings
        for i in 0..results_box.count {
            let result = &*results_box.results.add(i);
            if !result.id.is_null() {
                drop(CString::from_raw(result.id));
            }
            if !result.title.is_null() {
                drop(CString::from_raw(result.title));
            }
            if !result.category.is_null() {
                drop(CString::from_raw(result.category));
            }
            if !result.summary.is_null() {
                drop(CString::from_raw(result.summary));
            }
        }
        
        // Free the results array
        if !results_box.results.is_null() {
            Vec::from_raw_parts(results_box.results, results_box.count, results_box.count);
        }
    }
}

// Free an index manager
#[no_mangle]
pub extern "C" fn tantivy_free_index(index_ptr: *mut c_void) {
    if !index_ptr.is_null() {
        unsafe {
            drop(Box::from_raw(index_ptr as *mut IndexManager));
        }
    }
}

// Helper function to create the schema
fn create_schema() -> Schema {
    let mut schema_builder = Schema::builder();
    
    schema_builder.add_text_field("id", STORED | FAST);
    schema_builder.add_text_field("title", TEXT | STORED | FAST);
    schema_builder.add_text_field("category", STRING | STORED | FAST);
    schema_builder.add_u64_field("priority", STORED | FAST);
    schema_builder.add_text_field("summary", TEXT | STORED);
    schema_builder.add_text_field("content", TEXT);
    
    schema_builder.build()
}

// Get index statistics
#[repr(C)]
pub struct IndexStats {
    pub num_docs: u64,
    pub index_size_bytes: u64,
}

#[no_mangle]
pub extern "C" fn tantivy_get_index_stats(index_ptr: *mut c_void) -> IndexStats {
    if index_ptr.is_null() {
        return IndexStats {
            num_docs: 0,
            index_size_bytes: 0,
        };
    }

    let manager = unsafe { &*(index_ptr as *const IndexManager) };
    
    let reader_guard = match manager.reader.read() {
        Ok(guard) => guard,
        Err(_) => return IndexStats {
            num_docs: 0,
            index_size_bytes: 0,
        },
    };
    
    let searcher = reader_guard.searcher();
    let num_docs = searcher.num_docs();
    
    // Estimate index size (this is a simplification)
    let index_size_bytes = num_docs * 1024; // Rough estimate
    
    IndexStats {
        num_docs,
        index_size_bytes,
    }
}