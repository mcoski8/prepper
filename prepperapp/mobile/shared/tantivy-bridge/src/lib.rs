use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::catch_unwind;
use std::ptr;
use serde::{Serialize, Deserialize};
use serde_json;
use tantivy::{Index, IndexReader, ReloadPolicy};
use tantivy::query::QueryParser;
use tantivy::collector::TopDocs;

// Opaque type for the searcher
pub struct TantivySearcher {
    index: Index,
    reader: IndexReader,
}

// JSON response types
#[derive(Serialize, Deserialize)]
struct InitSuccess {
    searcher_ptr: usize,
}

#[derive(Serialize, Deserialize)]
struct InitResponse {
    #[serde(skip_serializing_if = "Option::is_none")]
    success: Option<InitSuccess>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[derive(Serialize, Deserialize)]
struct SearchItem {
    doc_id: String,
    score: f32,
    title: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    snippet: Option<String>,
}

#[derive(Serialize, Deserialize)]
struct SearchResponse {
    #[serde(skip_serializing_if = "Option::is_none")]
    success: Option<Vec<SearchItem>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

// Helper to convert result to JSON C string
fn to_json_cstring<T: Serialize>(value: &T) -> *mut c_char {
    match serde_json::to_string(value) {
        Ok(json) => match CString::new(json) {
            Ok(cstr) => cstr.into_raw(),
            Err(_) => {
                let error = InitResponse {
                    success: None,
                    error: Some("Failed to create C string".to_string()),
                };
                CString::new(serde_json::to_string(&error).unwrap()).unwrap().into_raw()
            }
        },
        Err(e) => {
            let error = InitResponse {
                success: None,
                error: Some(format!("JSON serialization failed: {}", e)),
            };
            CString::new(serde_json::to_string(&error).unwrap()).unwrap().into_raw()
        }
    }
}

#[no_mangle]
pub extern "C" fn init_searcher(path: *const c_char) -> *mut c_char {
    catch_unwind(|| {
        // Parse path
        let path_str = unsafe {
            match CStr::from_ptr(path).to_str() {
                Ok(s) => s,
                Err(_) => {
                    let response = InitResponse {
                        success: None,
                        error: Some("Invalid UTF-8 in path".to_string()),
                    };
                    return to_json_cstring(&response);
                }
            }
        };
        
        // Open index
        let index = match Index::open_in_dir(path_str) {
            Ok(idx) => idx,
            Err(e) => {
                let response = InitResponse {
                    success: None,
                    error: Some(format!("Failed to open index: {}", e)),
                };
                return to_json_cstring(&response);
            }
        };
        
        // Create reader
        let reader = match index
            .reader_builder()
            .reload_policy(ReloadPolicy::Manual)
            .try_into() {
            Ok(r) => r,
            Err(e) => {
                let response = InitResponse {
                    success: None,
                    error: Some(format!("Failed to create reader: {}", e)),
                };
                return to_json_cstring(&response);
            }
        };
        
        // Create searcher struct
        let searcher = Box::new(TantivySearcher {
            index,
            reader,
        });
        
        let ptr = Box::into_raw(searcher) as usize;
        
        let response = InitResponse {
            success: Some(InitSuccess { searcher_ptr: ptr }),
            error: None,
        };
        
        to_json_cstring(&response)
    }).unwrap_or_else(|_| {
        let response = InitResponse {
            success: None,
            error: Some("Panic occurred during initialization".to_string()),
        };
        to_json_cstring(&response)
    })
}

#[no_mangle]
pub extern "C" fn close_searcher(searcher_ptr: *mut TantivySearcher) {
    if searcher_ptr.is_null() {
        return;
    }
    unsafe {
        let _ = Box::from_raw(searcher_ptr);
    }
}

#[no_mangle]
pub extern "C" fn search(
    searcher_ptr: *const TantivySearcher,
    query: *const c_char,
    limit: u32,
    offset: u32,
) -> *mut c_char {
    catch_unwind(|| {
        // Validate searcher pointer
        if searcher_ptr.is_null() {
            let response = SearchResponse {
                success: None,
                error: Some("Null searcher pointer".to_string()),
            };
            return to_json_cstring(&response);
        }
        
        let searcher = unsafe { &*searcher_ptr };
        
        // Parse query
        let query_str = unsafe {
            match CStr::from_ptr(query).to_str() {
                Ok(s) => s,
                Err(_) => {
                    let response = SearchResponse {
                        success: None,
                        error: Some("Invalid UTF-8 in query".to_string()),
                    };
                    return to_json_cstring(&response);
                }
            }
        };
        
        // Get searcher
        let tantivy_searcher = searcher.reader.searcher();
        
        // Setup query parser
        let schema = searcher.index.schema();
        let default_fields = vec![
            schema.get_field("title").unwrap(),
            schema.get_field("content").unwrap(),
        ];
        
        let query_parser = QueryParser::for_index(&searcher.index, default_fields);
        
        // Parse query
        let parsed_query = match query_parser.parse_query(query_str) {
            Ok(q) => q,
            Err(e) => {
                let response = SearchResponse {
                    success: None,
                    error: Some(format!("Query parse error: {}", e)),
                };
                return to_json_cstring(&response);
            }
        };
        
        // Search with offset
        let collector = TopDocs::with_limit(limit as usize + offset as usize);
        let top_docs = match tantivy_searcher.search(&parsed_query, &collector) {
            Ok(docs) => docs,
            Err(e) => {
                let response = SearchResponse {
                    success: None,
                    error: Some(format!("Search error: {}", e)),
                };
                return to_json_cstring(&response);
            }
        };
        
        // Convert results, skipping offset
        let mut results = Vec::new();
        for (i, (score, doc_address)) in top_docs.into_iter().enumerate() {
            if i < offset as usize {
                continue;
            }
            if i >= (offset + limit) as usize {
                break;
            }
            
            if let Ok(doc) = tantivy_searcher.doc(doc_address) {
                // Extract fields from document
                let doc_id = doc.get_first(schema.get_field("id").unwrap())
                    .and_then(|v| v.as_text())
                    .unwrap_or("unknown")
                    .to_string();
                    
                let title = doc.get_first(schema.get_field("title").unwrap())
                    .and_then(|v| v.as_text())
                    .unwrap_or("Untitled")
                    .to_string();
                    
                let snippet = doc.get_first(schema.get_field("content").unwrap())
                    .and_then(|v| v.as_text())
                    .map(|s| s.chars().take(200).collect::<String>() + "...");
                
                results.push(SearchItem {
                    doc_id,
                    score,
                    title,
                    snippet,
                });
            }
        }
        
        let response = SearchResponse {
            success: Some(results),
            error: None,
        };
        
        to_json_cstring(&response)
    }).unwrap_or_else(|_| {
        let response = SearchResponse {
            success: None,
            error: Some("Panic occurred during search".to_string()),
        };
        to_json_cstring(&response)
    })
}

#[no_mangle]
pub extern "C" fn free_string(s: *mut c_char) {
    if s.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(s);
    }
}