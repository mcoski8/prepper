// multi_search.rs - Multi-module search functionality

use crate::ffi::SearchService;
use rayon::prelude::*;
use std::collections::{HashMap, HashSet};
use std::ffi::{c_char, CStr, CString};
use std::sync::Mutex;
use tantivy::collector::TopDocs;
use tantivy::{TantivyDocument, schema::Value};

// The opaque handle for the FFI layer
pub struct MultiSearchManager {
    // Using a Mutex to ensure thread-safe access
    services: Mutex<HashMap<String, Box<SearchService>>>,
}

// Configuration for a multi-search, passed from native code as JSON
#[derive(serde::Deserialize)]
struct MultiSearchConfig {
    #[serde(default = "default_limit")]
    limit: usize,
    #[serde(default)]
    weights: HashMap<String, f32>,
    #[serde(default)]
    module_filter: Option<Vec<String>>, // Optional: only search specific modules
}

fn default_limit() -> usize {
    20
}

// Extended search result with module information
#[derive(serde::Serialize, Clone)]
struct MultiSearchResultItem {
    doc_id: String,
    title: String,
    summary: String,
    score: f32,
    module: String,
}

// Initialize multi-search manager with thread pool configuration
#[no_mangle]
pub extern "C" fn init_multi_manager() -> *mut MultiSearchManager {
    // One-time setup for Rayon's thread pool
    static INIT: std::sync::Once = std::sync::Once::new();
    INIT.call_once(|| {
        // Use 4 threads for mobile devices - balances performance and battery
        let _ = rayon::ThreadPoolBuilder::new()
            .num_threads(4)
            .thread_name(|idx| format!("tantivy-search-{}", idx))
            .build_global();
    });

    let manager = MultiSearchManager {
        services: Mutex::new(HashMap::new()),
    };
    Box::into_raw(Box::new(manager))
}

// Destroy the multi-search manager
#[no_mangle]
pub extern "C" fn destroy_multi_manager(manager_ptr: *mut MultiSearchManager) {
    if !manager_ptr.is_null() {
        let manager = unsafe { Box::from_raw(manager_ptr) };
        // Services will be dropped automatically when the HashMap is dropped
        drop(manager);
    }
}

// Load an index as a named module
#[no_mangle]
pub extern "C" fn multi_manager_load_index(
    manager_ptr: *mut MultiSearchManager,
    module_name_ptr: *const c_char,
    index_path_ptr: *const c_char,
) -> i32 {
    if manager_ptr.is_null() || module_name_ptr.is_null() || index_path_ptr.is_null() {
        return -1;
    }

    let manager = unsafe { &*manager_ptr };
    
    // Parse module name
    let module_name = unsafe {
        match CStr::from_ptr(module_name_ptr).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return -1,
        }
    };

    // Initialize the SearchService for this module
    let service_ptr = crate::ffi::init_searcher(index_path_ptr);
    if service_ptr.is_null() {
        return -1;
    }

    // Convert the raw pointer back to a Box to manage ownership
    let service = unsafe { Box::from_raw(service_ptr) };

    // Add to the manager
    match manager.services.lock() {
        Ok(mut services) => {
            services.insert(module_name, service);
            0
        }
        Err(_) => -1,
    }
}

// Unload a specific module
#[no_mangle]
pub extern "C" fn multi_manager_unload_index(
    manager_ptr: *mut MultiSearchManager,
    module_name_ptr: *const c_char,
) -> i32 {
    if manager_ptr.is_null() || module_name_ptr.is_null() {
        return -1;
    }

    let manager = unsafe { &*manager_ptr };
    
    let module_name = unsafe {
        match CStr::from_ptr(module_name_ptr).to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        }
    };

    match manager.services.lock() {
        Ok(mut services) => {
            if services.remove(module_name).is_some() {
                0
            } else {
                -1 // Module not found
            }
        }
        Err(_) => -1,
    }
}

// Trigger a reload for a specific module
#[no_mangle]
pub extern "C" fn multi_manager_reload_index(
    manager_ptr: *mut MultiSearchManager,
    module_name_ptr: *const c_char,
) -> i32 {
    if manager_ptr.is_null() || module_name_ptr.is_null() {
        return -1;
    }

    let manager = unsafe { &*manager_ptr };
    
    let module_name = unsafe {
        match CStr::from_ptr(module_name_ptr).to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        }
    };

    match manager.services.lock() {
        Ok(services) => {
            if let Some(service) = services.get(module_name) {
                // Use the trigger_index_reload function from our FFI module
                let service_ptr = service.as_ref() as *const SearchService as *mut SearchService;
                crate::ffi::trigger_index_reload(service_ptr)
            } else {
                -1 // Module not found
            }
        }
        Err(_) => -1,
    }
}

// The core multi-search function
#[no_mangle]
pub extern "C" fn multi_manager_search(
    manager_ptr: *const MultiSearchManager,
    query_ptr: *const c_char,
    config_json_ptr: *const c_char,
) -> *const c_char {
    if manager_ptr.is_null() || query_ptr.is_null() {
        return std::ptr::null();
    }

    let manager = unsafe { &*manager_ptr };
    
    // Parse query
    let query_str = unsafe {
        match CStr::from_ptr(query_ptr).to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null(),
        }
    };

    // Parse config (use defaults if not provided)
    let config: MultiSearchConfig = if config_json_ptr.is_null() {
        MultiSearchConfig {
            limit: default_limit(),
            weights: HashMap::new(),
            module_filter: None,
        }
    } else {
        let config_str = unsafe {
            match CStr::from_ptr(config_json_ptr).to_str() {
                Ok(s) => s,
                Err(_) => return std::ptr::null(),
            }
        };
        match serde_json::from_str(config_str) {
            Ok(c) => c,
            Err(_) => return std::ptr::null(),
        }
    };

    // Get services to search
    let services = match manager.services.lock() {
        Ok(s) => s,
        Err(_) => return std::ptr::null(),
    };

    // Filter modules if specified
    let modules_to_search: Vec<(&String, &Box<SearchService>)> = if let Some(filter) = &config.module_filter {
        services
            .iter()
            .filter(|(name, _)| filter.contains(name))
            .collect()
    } else {
        services.iter().collect()
    };

    // Perform parallel search
    let all_results: Vec<Vec<MultiSearchResultItem>> = modules_to_search
        .par_iter()
        .map(|(module_name, service)| {
            // Get weight for this module (default to 1.0)
            let weight = config.weights.get(*module_name).unwrap_or(&1.0);
            
            // Perform search using the service
            let searcher = service.reader.searcher();
            let query = match service.query_parser.parse_query(query_str) {
                Ok(q) => q,
                Err(_) => return Vec::new(),
            };

            let top_docs = match searcher.search(&query, &TopDocs::with_limit(config.limit)) {
                Ok(td) => td,
                Err(_) => return Vec::new(),
            };

            // Convert results
            let mut module_results = Vec::new();
            for (score, doc_address) in top_docs {
                if let Ok(doc) = searcher.doc::<TantivyDocument>(doc_address) {
                    let doc_id = doc.get_first(service.schema.get_field("id").unwrap())
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string();
                    let title = doc.get_first(service.schema.get_field("title").unwrap())
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string();
                    let summary = doc.get_first(service.schema.get_field("summary").unwrap())
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string();

                    module_results.push(MultiSearchResultItem {
                        doc_id,
                        title,
                        summary,
                        score: score * weight,
                        module: module_name.to_string(),
                    });
                }
            }
            module_results
        })
        .collect();

    // Flatten and merge results
    let mut merged_results: Vec<MultiSearchResultItem> = all_results
        .into_iter()
        .flatten()
        .collect();

    // Sort by score (descending)
    merged_results.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap());

    // Deduplicate by doc_id (keeping highest scoring version)
    let mut seen_ids = HashSet::new();
    let mut final_results = Vec::new();
    
    for result in merged_results {
        if seen_ids.insert(result.doc_id.clone()) {
            final_results.push(result);
            if final_results.len() >= config.limit {
                break;
            }
        }
    }

    // Serialize to JSON
    match serde_json::to_string(&final_results) {
        Ok(json) => CString::new(json).map_or(std::ptr::null(), |s| s.into_raw()),
        Err(_) => std::ptr::null(),
    }
}

// Get statistics for all loaded modules
#[derive(serde::Serialize)]
struct ModuleStats {
    name: String,
    num_docs: u64,
    estimated_size_bytes: u64,
}

#[no_mangle]
pub extern "C" fn multi_manager_get_stats(manager_ptr: *const MultiSearchManager) -> *const c_char {
    if manager_ptr.is_null() {
        return std::ptr::null();
    }

    let manager = unsafe { &*manager_ptr };
    
    let services = match manager.services.lock() {
        Ok(s) => s,
        Err(_) => return std::ptr::null(),
    };

    let stats: Vec<ModuleStats> = services
        .iter()
        .map(|(name, service)| {
            let searcher = service.reader.searcher();
            let num_docs = searcher.num_docs();
            
            ModuleStats {
                name: name.clone(),
                num_docs,
                estimated_size_bytes: num_docs * 1024, // Rough estimate
            }
        })
        .collect();

    match serde_json::to_string(&stats) {
        Ok(json) => CString::new(json).map_or(std::ptr::null(), |s| s.into_raw()),
        Err(_) => std::ptr::null(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_multi_manager_lifecycle() {
        let manager_ptr = init_multi_manager();
        assert!(!manager_ptr.is_null());
        
        destroy_multi_manager(manager_ptr);
    }

    #[test]
    fn test_null_safety() {
        assert_eq!(multi_manager_load_index(std::ptr::null_mut(), std::ptr::null(), std::ptr::null()), -1);
        assert_eq!(multi_manager_reload_index(std::ptr::null_mut(), std::ptr::null()), -1);
        assert!(multi_manager_search(std::ptr::null(), std::ptr::null(), std::ptr::null()).is_null());
        
        destroy_multi_manager(std::ptr::null_mut()); // Should not crash
    }
}