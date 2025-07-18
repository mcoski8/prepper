// ffi.rs - FFI interface for mobile integration

use std::ffi::{c_char, CStr, CString};
use tantivy::collector::TopDocs;
use tantivy::query::QueryParser;
use tantivy::{schema::{Schema, Value}, Index, IndexReader, TantivyDocument};

// This struct is our opaque handle. The native side only knows it as a pointer.
// No #[repr(C)] is needed because we aren't accessing its fields from the C side.
pub struct SearchService {
    pub(crate) reader: IndexReader,
    pub(crate) schema: Schema,
    pub(crate) query_parser: QueryParser,
}

// A struct to define the format of our search results.
// This will be serialized to JSON.
#[derive(serde::Serialize)]
struct SearchResultItem {
    doc_id: String,
    title: String,
    summary: String,
    score: f32,
}

/// Initializes the SearchService and returns an opaque pointer to it.
///
/// # Safety
/// The `index_path_ptr` must be a valid, null-terminated C string.
/// The returned pointer must be passed to `destroy_searcher` to avoid memory leaks.
/// Returns null on failure (e.g., index not found, invalid path).
#[no_mangle]
pub extern "C" fn init_searcher(index_path_ptr: *const c_char) -> *mut SearchService {
    if index_path_ptr.is_null() {
        return std::ptr::null_mut();
    }
    
    // Use catch_unwind to ensure no panics cross the FFI boundary.
    let result = std::panic::catch_unwind(|| -> Result<*mut SearchService, Box<dyn std::error::Error>> {
        let path_cstr = unsafe { CStr::from_ptr(index_path_ptr) };
        let index_path = path_cstr.to_str()?;

        let index = Index::open_in_dir(index_path)?;
        let schema = index.schema();
        let reader = index.reader_builder().reload_policy(tantivy::ReloadPolicy::Manual).try_into()?;

        // Define which fields are used for searching.
        let title_field = schema.get_field("title").map_err(|_| "title field not found")?;
        let body_field = schema.get_field("body").map_err(|_| "body field not found")?;
        let summary_field = schema.get_field("summary").map_err(|_| "summary field not found")?;
        let query_parser = QueryParser::for_index(&index, vec![title_field, summary_field, body_field]);

        let service = SearchService { reader, schema, query_parser };
        let service_box = Box::new(service);
        Ok(Box::into_raw(service_box))
    });

    match result {
        // Here we are returning a Result<*mut SearchService, _> so we need to handle it
        Ok(Ok(ptr)) => ptr,
        _ => std::ptr::null_mut(),
    }
}

/// Destroys the SearchService instance.
///
/// # Safety
/// The `service_ptr` must be a pointer originally returned by `init_searcher`.
/// Using the pointer after calling this function is undefined behavior.
#[no_mangle]
pub extern "C" fn destroy_searcher(service_ptr: *mut SearchService) {
    if !service_ptr.is_null() {
        let _ = unsafe { Box::from_raw(service_ptr) };
    }
}

/// Performs a search and returns results as a JSON string.
///
/// # Safety
/// `service_ptr` must be a valid pointer from `init_searcher`.
/// `query_ptr` must be a valid, null-terminated C string.
/// The returned string pointer must be freed with `free_string`.
/// Returns null on failure.
#[no_mangle]
pub extern "C" fn search(service_ptr: *const SearchService, query_ptr: *const c_char) -> *const c_char {
    if service_ptr.is_null() || query_ptr.is_null() {
        return std::ptr::null();
    }

    let service = unsafe { &*service_ptr };
    let query_cstr = unsafe { CStr::from_ptr(query_ptr) };

    let query_str = match query_cstr.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null(),
    };

    let searcher = service.reader.searcher();
    let query = match service.query_parser.parse_query(query_str) {
        Ok(q) => q,
        Err(_) => return std::ptr::null(), // Invalid query syntax
    };

    let top_docs = match searcher.search(&query, &TopDocs::with_limit(20)) {
        Ok(td) => td,
        Err(_) => return std::ptr::null(),
    };

    let mut results: Vec<SearchResultItem> = Vec::new();
    for (score, doc_address) in top_docs {
        if let Ok(doc) = searcher.doc::<TantivyDocument>(doc_address) {
            let title = doc.get_first(service.schema.get_field("title").unwrap())
                .and_then(|v| v.as_str()).unwrap_or("").to_string();
            let doc_id = doc.get_first(service.schema.get_field("id").unwrap())
                .and_then(|v| v.as_str()).unwrap_or("").to_string();
            let summary = doc.get_first(service.schema.get_field("summary").unwrap())
                .and_then(|v| v.as_str()).unwrap_or("").to_string();
            results.push(SearchResultItem { doc_id, title, summary, score });
        }
    }

    let json_string = match serde_json::to_string(&results) {
        Ok(s) => s,
        Err(_) => return std::ptr::null(),
    };

    CString::new(json_string).map_or(std::ptr::null(), |s| s.into_raw())
}

/// Gets a document by ID and returns it as a JSON string.
///
/// # Safety
/// `service_ptr` must be a valid pointer from `init_searcher`.
/// `doc_id_ptr` must be a valid, null-terminated C string.
/// The returned string pointer must be freed with `free_string`.
/// Returns null on failure.
#[no_mangle]
pub extern "C" fn get_document(service_ptr: *const SearchService, doc_id_ptr: *const c_char) -> *const c_char {
    if service_ptr.is_null() || doc_id_ptr.is_null() {
        return std::ptr::null();
    }

    let service = unsafe { &*service_ptr };
    let doc_id_cstr = unsafe { CStr::from_ptr(doc_id_ptr) };

    let doc_id = match doc_id_cstr.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null(),
    };

    // Create a query for the specific document ID
    let id_field = match service.schema.get_field("id") {
        Ok(f) => f,
        Err(_) => return std::ptr::null(),
    };

    let searcher = service.reader.searcher();
    let query = tantivy::query::TermQuery::new(
        tantivy::Term::from_field_text(id_field, doc_id),
        tantivy::schema::IndexRecordOption::WithFreqsAndPositions,
    );

    let top_docs = match searcher.search(&query, &TopDocs::with_limit(1)) {
        Ok(td) => td,
        Err(_) => return std::ptr::null(),
    };

    if let Some((_, doc_address)) = top_docs.first() {
        if let Ok(doc) = searcher.doc::<TantivyDocument>(*doc_address) {
            // Create a full document result with all fields
            let mut doc_map = std::collections::HashMap::new();
            
            // Get all fields from schema and extract their values
            for (field, field_entry) in service.schema.fields() {
                let field_name = field_entry.name();
                if let Some(field_value) = doc.get_first(field) {
                    if let Some(text_value) = field_value.as_str() {
                        doc_map.insert(field_name.to_string(), text_value.to_string());
                    }
                }
            }

            match serde_json::to_string(&doc_map) {
                Ok(s) => CString::new(s).map_or(std::ptr::null(), |s| s.into_raw()),
                Err(_) => std::ptr::null(),
            }
        } else {
            std::ptr::null()
        }
    } else {
        std::ptr::null()
    }
}

/// Triggers a reload of the index reader to pick up changes from disk.
/// Returns 0 on success, -1 on failure.
#[no_mangle]
pub extern "C" fn trigger_index_reload(service_ptr: *mut SearchService) -> i32 {
    if service_ptr.is_null() {
        return -1;
    }
    let service = unsafe { &mut *service_ptr };
    match service.reader.reload() {
        Ok(_) => 0,
        Err(_) => -1,
    }
}

/// Frees a string that was allocated on the Rust side.
///
/// # Safety
/// The pointer must be one returned from a Rust FFI function like `search`.
#[no_mangle]
pub extern "C" fn free_string(s: *mut c_char) {
    if !s.is_null() {
        let _ = unsafe { CString::from_raw(s) };
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_null_safety() {
        assert!(init_searcher(std::ptr::null()).is_null());
        assert!(search(std::ptr::null(), std::ptr::null()).is_null());
        assert_eq!(trigger_index_reload(std::ptr::null_mut()), -1);
        
        // Should not crash
        destroy_searcher(std::ptr::null_mut());
        free_string(std::ptr::null_mut());
    }
}