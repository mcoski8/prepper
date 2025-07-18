mod ffi;
mod multi_search;

// Re-export FFI functions for mobile bindings
pub use ffi::*;
pub use multi_search::*;

// Initialize logging for mobile platforms (common to both implementations)
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