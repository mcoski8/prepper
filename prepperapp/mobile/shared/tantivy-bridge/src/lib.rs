use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic;
use std::path::Path;
use std::ptr;

use tantivy::collector::TopDocs;
use tantivy::query::QueryParser;
use tantivy::schema::*;
use tantivy::{Index, IndexReader, ReloadPolicy};

/// Error codes matching bindings.h
#[repr(C)]
pub enum TantivyError {
    Ok = 0,
    InvalidPath = 1,
    IndexCorrupt = 2,
    QueryParse = 3,
    OutOfMemory = 4,
    Unknown = 99,
}

/// Search result structure (C-compatible)
#[repr(C)]
pub struct SearchResult {
    pub article_id: *mut c_char,
    pub title: *mut c_char,
    pub snippet: *mut c_char,
    pub score: f32,
    pub priority: u32,
}

/// Search results collection
#[repr(C)]
pub struct SearchResults {
    pub results: *mut SearchResult,
    pub count: u32,
    pub total_hits: u32,
}

/// Opaque handle for the Tantivy index
pub struct TantivyIndex {
    index: Index,
    reader: IndexReader,
    query_parser: QueryParser,
    schema: Schema,
}

/// Convert Rust string to C string, returning null on failure
fn to_c_string(s: &str) -> *mut c_char {
    match CString::new(s) {
        Ok(c_str) => c_str.into_raw(),
        Err(_) => ptr::null_mut(),
    }
}

/// Convert C string to Rust string
unsafe fn from_c_str(s: *const c_char) -> Result<String, TantivyError> {
    if s.is_null() {
        return Err(TantivyError::InvalidPath);
    }
    
    match CStr::from_ptr(s).to_str() {
        Ok(str) => Ok(str.to_string()),
        Err(_) => Err(TantivyError::InvalidPath),
    }
}

/// Initialize a Tantivy index from the given path
#[no_mangle]
pub unsafe extern "C" fn tantivy_index_open(
    index_path: *const c_char,
    handle_out: *mut *mut TantivyIndex,
) -> TantivyError {
    // Wrap in catch_unwind to prevent panics from crossing FFI boundary
    let result = panic::catch_unwind(|| {
        let path_str = match from_c_str(index_path) {
            Ok(s) => s,
            Err(e) => return e,
        };
        
        let path = Path::new(&path_str);
        
        // Open the index
        let index = match Index::open_in_dir(path) {
            Ok(idx) => idx,
            Err(_) => return TantivyError::IndexCorrupt,
        };
        
        // Create reader with no automatic reloading
        let reader = match index.reader_builder()
            .reload_policy(ReloadPolicy::Manual)
            .try_into() {
            Ok(r) => r,
            Err(_) => return TantivyError::Unknown,
        };
        
        // Get schema and setup query parser
        let schema = index.schema();
        
        // Assume we have a "content" field for search
        let content_field = match schema.get_field("content") {
            Ok(f) => f,
            Err(_) => return TantivyError::IndexCorrupt,
        };
        
        let query_parser = QueryParser::for_index(&index, vec![content_field]);
        
        // Create handle
        let handle = Box::new(TantivyIndex {
            index,
            reader,
            query_parser,
            schema,
        });
        
        *handle_out = Box::into_raw(handle);
        TantivyError::Ok
    });
    
    match result {
        Ok(error) => error,
        Err(_) => TantivyError::Unknown,
    }
}

/// Close and free a Tantivy index
#[no_mangle]
pub unsafe extern "C" fn tantivy_index_close(handle: *mut TantivyIndex) {
    if !handle.is_null() {
        let _ = Box::from_raw(handle);
    }
}

/// Search the index with a query string
#[no_mangle]
pub unsafe extern "C" fn tantivy_search(
    handle: *mut TantivyIndex,
    query: *const c_char,
    max_results: u32,
    results_out: *mut *mut SearchResults,
) -> TantivyError {
    if handle.is_null() || results_out.is_null() {
        return TantivyError::Unknown;
    }
    
    let result = panic::catch_unwind(|| {
        let index = &*handle;
        let query_str = match from_c_str(query) {
            Ok(s) => s,
            Err(e) => return e,
        };
        
        // Parse query
        let query = match index.query_parser.parse_query(&query_str) {
            Ok(q) => q,
            Err(_) => return TantivyError::QueryParse,
        };
        
        // Search
        let searcher = index.reader.searcher();
        let top_docs = match searcher.search(&query, &TopDocs::with_limit(max_results as usize)) {
            Ok(docs) => docs,
            Err(_) => return TantivyError::Unknown,
        };
        
        // Convert results to C-compatible format
        let mut c_results = Vec::with_capacity(top_docs.len());
        
        let id_field = index.schema.get_field("id").unwrap();
        let title_field = index.schema.get_field("title").unwrap();
        
        for (score, doc_address) in top_docs {
            let doc = match searcher.doc(doc_address) {
                Ok(d) => d,
                Err(_) => continue,
            };
            
            let id = doc.get_first(id_field)
                .and_then(|v| v.as_str())
                .unwrap_or("");
            
            let title = doc.get_first(title_field)
                .and_then(|v| v.as_str())
                .unwrap_or("");
            
            c_results.push(SearchResult {
                article_id: to_c_string(id),
                title: to_c_string(title),
                snippet: to_c_string(""), // TODO: Generate snippets
                score,
                priority: 0, // TODO: Extract from metadata
            });
        }
        
        let results = Box::new(SearchResults {
            results: c_results.as_mut_ptr(),
            count: c_results.len() as u32,
            total_hits: c_results.len() as u32, // TODO: Get actual total
        });
        
        std::mem::forget(c_results); // Prevent deallocation
        *results_out = Box::into_raw(results);
        
        TantivyError::Ok
    });
    
    match result {
        Ok(error) => error,
        Err(_) => TantivyError::Unknown,
    }
}

/// Free search results
#[no_mangle]
pub unsafe extern "C" fn tantivy_free_results(results: *mut SearchResults) {
    if !results.is_null() {
        let results = Box::from_raw(results);
        
        // Free individual strings
        for i in 0..results.count {
            let result = &*results.results.add(i as usize);
            if !result.article_id.is_null() {
                let _ = CString::from_raw(result.article_id);
            }
            if !result.title.is_null() {
                let _ = CString::from_raw(result.title);
            }
            if !result.snippet.is_null() {
                let _ = CString::from_raw(result.snippet);
            }
        }
        
        // Free results array
        Vec::from_raw_parts(results.results, results.count as usize, results.count as usize);
    }
}

/// Get error message
#[no_mangle]
pub extern "C" fn tantivy_error_message(error: TantivyError) -> *const c_char {
    let msg = match error {
        TantivyError::Ok => "Success\0",
        TantivyError::InvalidPath => "Invalid index path\0",
        TantivyError::IndexCorrupt => "Index is corrupted or incompatible\0",
        TantivyError::QueryParse => "Failed to parse search query\0",
        TantivyError::OutOfMemory => "Out of memory\0",
        TantivyError::Unknown => "Unknown error\0",
    };
    msg.as_ptr() as *const c_char
}

/// Check index health
#[no_mangle]
pub unsafe extern "C" fn tantivy_index_is_healthy(handle: *mut TantivyIndex) -> bool {
    if handle.is_null() {
        return false;
    }
    
    panic::catch_unwind(|| {
        let index = &*handle;
        // Try to get searcher as health check
        let _ = index.reader.searcher();
        true
    }).unwrap_or(false)
}

/// Get index statistics
#[no_mangle]
pub unsafe extern "C" fn tantivy_index_stats(
    handle: *mut TantivyIndex,
    doc_count_out: *mut u64,
    index_size_bytes_out: *mut u64,
) -> TantivyError {
    if handle.is_null() || doc_count_out.is_null() || index_size_bytes_out.is_null() {
        return TantivyError::Unknown;
    }
    
    let result = panic::catch_unwind(|| {
        let index = &*handle;
        let searcher = index.reader.searcher();
        
        *doc_count_out = searcher.num_docs();
        *index_size_bytes_out = 0; // TODO: Calculate actual size
        
        TantivyError::Ok
    });
    
    match result {
        Ok(error) => error,
        Err(_) => TantivyError::Unknown,
    }
}