import XCTest

class TantivyBridgeTests: XCTestCase {
    
    var testIndexPath: String!
    var bridge: TantivyBridge!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create temp directory for test index
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("TantivyTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        testIndexPath = testDir.path
        
        // Initialize logging
        TantivyBridge.initializeLogging()
        
        // Create test index
        bridge = try TantivyBridge.createIndex(at: testIndexPath)
    }
    
    override func tearDown() async throws {
        // Clean up
        bridge = nil
        if let path = testIndexPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        
        try await super.tearDown()
    }
    
    // MARK: - Tests
    
    func testIndexCreation() async throws {
        // Index should be created successfully in setUp
        XCTAssertNotNil(bridge)
        
        // Should be able to get stats
        let stats = await bridge.getStats()
        XCTAssertEqual(stats.documentCount, 0)
    }
    
    func testDocumentIndexing() async throws {
        // Add a document
        try await bridge.addDocument(
            id: "test-001",
            title: "Test Document",
            category: "Test",
            priority: 3,
            summary: "This is a test document",
            content: "This is the content of the test document for searching"
        )
        
        // Commit
        try await bridge.commit()
        
        // Check stats
        let stats = await bridge.getStats()
        XCTAssertEqual(stats.documentCount, 1)
    }
    
    func testSearch() async throws {
        // Add multiple documents
        let documents = [
            (
                id: "med-001",
                title: "Severe Bleeding Control",
                category: "Medical",
                priority: 5,
                summary: "How to stop severe bleeding",
                content: "Apply direct pressure to stop bleeding. Use a tourniquet if necessary."
            ),
            (
                id: "water-001",
                title: "Water Purification",
                category: "Water",
                priority: 5,
                summary: "Making water safe to drink",
                content: "Boil water for one minute to kill pathogens. Use purification tablets as backup."
            ),
            (
                id: "fire-001",
                title: "Starting Fire Without Matches",
                category: "Fire",
                priority: 3,
                summary: "Primitive fire starting methods",
                content: "Use friction methods like bow drill or flint and steel to start fire."
            )
        ]
        
        try await bridge.addDocuments(documents)
        
        // Search for "bleeding"
        let bleedingResults = try await bridge.search(query: "bleeding", limit: 10)
        XCTAssertEqual(bleedingResults.count, 1)
        XCTAssertEqual(bleedingResults.first?.id, "med-001")
        
        // Search for "water"
        let waterResults = try await bridge.search(query: "water", limit: 10)
        XCTAssertEqual(waterResults.count, 1)
        XCTAssertEqual(waterResults.first?.id, "water-001")
        
        // Search for "fire"
        let fireResults = try await bridge.search(query: "fire", limit: 10)
        XCTAssertEqual(fireResults.count, 1)
        XCTAssertEqual(fireResults.first?.id, "fire-001")
        
        // Multi-term search
        let multiResults = try await bridge.search(query: "purification methods", limit: 10)
        XCTAssertGreaterThan(multiResults.count, 0)
    }
    
    func testSearchPerformance() async throws {
        // Add 100 documents
        var documents: [(String, String, String, Int, String, String)] = []
        
        for i in 0..<100 {
            documents.append((
                id: "doc-\(i)",
                title: "Document \(i): Emergency Procedure",
                category: ["Medical", "Water", "Fire", "Shelter"].randomElement()!,
                priority: Int.random(in: 1...5),
                summary: "Summary for document \(i) with important survival information",
                content: "This is the detailed content for document \(i). It contains various keywords like bleeding, water, fire, shelter, emergency, survival, first aid, and treatment."
            ))
        }
        
        try await bridge.addDocuments(documents)
        
        // Measure search performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let results = try await bridge.search(query: "emergency", limit: 10)
        let searchTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // Convert to ms
        
        print("Search completed in \(searchTime)ms with \(results.count) results")
        
        // Should return results
        XCTAssertGreaterThan(results.count, 0)
        
        // Should complete in under 100ms
        XCTAssertLessThan(searchTime, 100.0, "Search took \(searchTime)ms, should be under 100ms")
    }
    
    func testConcurrentSearches() async throws {
        // Add test documents
        let documents = [
            ("med-001", "Bleeding Control", "Medical", 5, "Stop bleeding", "Direct pressure and tourniquets"),
            ("water-001", "Water Safety", "Water", 5, "Clean water", "Boiling and purification"),
            ("fire-001", "Fire Starting", "Fire", 3, "Make fire", "Friction and spark methods")
        ]
        
        try await bridge.addDocuments(documents)
        
        // Perform concurrent searches
        async let search1 = bridge.search(query: "bleeding", limit: 10)
        async let search2 = bridge.search(query: "water", limit: 10)
        async let search3 = bridge.search(query: "fire", limit: 10)
        
        let results = try await (search1, search2, search3)
        
        XCTAssertEqual(results.0.count, 1)
        XCTAssertEqual(results.1.count, 1)
        XCTAssertEqual(results.2.count, 1)
    }
    
    func testEmptySearch() async throws {
        // Search empty index
        let results = try await bridge.search(query: "test", limit: 10)
        XCTAssertEqual(results.count, 0)
    }
    
    func testSpecialCharacters() async throws {
        // Add document with special characters
        try await bridge.addDocument(
            id: "special-001",
            title: "First-Aid & CPR",
            category: "Medical",
            priority: 5,
            summary: "CPR (Cardio-Pulmonary Resuscitation)",
            content: "30:2 compression/breath ratio. 100-120 compressions/minute."
        )
        
        try await bridge.commit()
        
        // Search with special characters
        let results = try await bridge.search(query: "CPR", limit: 10)
        XCTAssertEqual(results.count, 1)
    }
}

// MARK: - Index Manager Tests
class TantivyIndexManagerTests: XCTestCase {
    
    var manager: TantivyIndexManager!
    
    override func setUp() async throws {
        try await super.setUp()
        manager = TantivyIndexManager()
    }
    
    func testInitialization() async throws {
        // Should initialize without errors
        try await manager.initializeCoreIndex()
        
        // Should have some default content
        let stats = await manager.getStats()
        XCTAssertGreaterThan(stats.documentCount, 0)
    }
    
    func testMultiIndexSearch() async throws {
        try await manager.initializeCoreIndex()
        
        // Search across indexes
        let results = try await manager.search(query: "bleeding", limit: 10)
        XCTAssertGreaterThan(results.count, 0)
        
        // Results should be sorted by score
        if results.count > 1 {
            for i in 1..<results.count {
                XCTAssertLessThanOrEqual(results[i].score, results[i-1].score)
            }
        }
    }
}