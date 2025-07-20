import Foundation

// MARK: - Tantivy C Bridge

// C function declarations
@_silgen_name("init_searcher")
func tantivy_init_searcher(_ path: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?

@_silgen_name("search")
func tantivy_search(_ searcher_ptr: UnsafeRawPointer,
                   _ query: UnsafePointer<CChar>,
                   _ limit: UInt32,
                   _ offset: UInt32) -> UnsafeMutablePointer<CChar>?

@_silgen_name("free_string")
func tantivy_free_string(_ str: UnsafeMutablePointer<CChar>)

@_silgen_name("close_searcher")
func tantivy_close_searcher(_ searcher_ptr: UnsafeMutableRawPointer)

// MARK: - TantivyBridge

class TantivyBridge {
    private var searcherPointer: UnsafeMutableRawPointer?
    private let queue = DispatchQueue(label: "com.prepperapp.tantivy", qos: .userInitiated)
    
    init() {}
    
    deinit {
        close()
    }
    
    // MARK: - Public Methods
    
    func initialize(indexPath: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: PrepperAppError.searchFailed("Bridge deallocated"))
                    return
                }
                
                // Call C function
                guard let resultPtr = tantivy_init_searcher(indexPath) else {
                    continuation.resume(throwing: PrepperAppError.searchFailed("Failed to initialize searcher"))
                    return
                }
                
                // Parse JSON response
                let resultString = String(cString: resultPtr)
                tantivy_free_string(resultPtr)
                
                do {
                    let data = resultString.data(using: .utf8)!
                    let response = try JSONDecoder().decode(InitResponse.self, from: data)
                    
                    if let success = response.success {
                        self.searcherPointer = UnsafeMutableRawPointer(bitPattern: success.searcherPtr)
                        continuation.resume()
                    } else if let error = response.error {
                        continuation.resume(throwing: PrepperAppError.searchFailed(error))
                    } else {
                        continuation.resume(throwing: PrepperAppError.searchFailed("Invalid response"))
                    }
                } catch {
                    continuation.resume(throwing: PrepperAppError.searchFailed("Failed to parse response: \(error)"))
                }
            }
        }
    }
    
    func search(query: String, limit: Int = 20, offset: Int = 0) async throws -> [TantivySearchResult] {
        guard let searcher = searcherPointer else {
            throw PrepperAppError.searchFailed("Searcher not initialized")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                // Call C function
                guard let resultPtr = tantivy_search(searcher, query, UInt32(limit), UInt32(offset)) else {
                    continuation.resume(throwing: PrepperAppError.searchFailed("Search failed"))
                    return
                }
                
                // Parse JSON response
                let resultString = String(cString: resultPtr)
                tantivy_free_string(resultPtr)
                
                do {
                    let data = resultString.data(using: .utf8)!
                    let response = try JSONDecoder().decode(SearchResponse.self, from: data)
                    
                    if let success = response.success {
                        let results = success.map { item in
                            TantivySearchResult(
                                docId: item.doc_id,
                                score: item.score,
                                title: item.title,
                                snippet: item.snippet
                            )
                        }
                        continuation.resume(returning: results)
                    } else if let error = response.error {
                        continuation.resume(throwing: PrepperAppError.searchFailed(error))
                    } else {
                        continuation.resume(returning: [])
                    }
                } catch {
                    continuation.resume(throwing: PrepperAppError.searchFailed("Failed to parse response: \(error)"))
                }
            }
        }
    }
    
    func close() {
        if let searcher = searcherPointer {
            queue.sync {
                tantivy_close_searcher(searcher)
                searcherPointer = nil
            }
        }
    }
    
    // MARK: - Private Types
    
    private struct InitResponse: Codable {
        struct Success: Codable {
            let searcherPtr: Int
            
            private enum CodingKeys: String, CodingKey {
                case searcherPtr = "searcher_ptr"
            }
        }
        
        let success: Success?
        let error: String?
    }
    
    private struct SearchResponse: Codable {
        struct SearchItem: Codable {
            let doc_id: String
            let score: Float
            let title: String
            let snippet: String?
        }
        
        let success: [SearchItem]?
        let error: String?
    }
}