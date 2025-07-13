import XCTest
@testable import StreamKitTestApp

@MainActor
final class STAGQueryServiceTests: XCTestCase {
    var stagService: STAGQueryService!
    
    override func setUp() async throws {
        stagService = STAGQueryService()
    }
    
    override func tearDown() async throws {
        stagService = nil
    }
    
    // MARK: - Initialization Tests
    func testSTAGServiceInitialization() {
        XCTAssertFalse(stagService.isLoading)
        XCTAssertNil(stagService.lastResult)
        XCTAssertNil(stagService.lastError)
    }
    
    // MARK: - Query Tests
    func testQuerySessionWithValidURL() async {
        let sessionID = "test-session-123"
        let stagURL = "http://localhost:8081/query"
        
        // Start the query
        await stagService.querySession(sessionID: sessionID, stagURL: stagURL)
        
        // Should complete without error
        XCTAssertFalse(stagService.isLoading)
        XCTAssertNotNil(stagService.lastResult)
        XCTAssertNil(stagService.lastError)
        
        // Check result properties
        let result = stagService.lastResult!
        XCTAssertGreaterThanOrEqual(result.anchors.count, 0)
        XCTAssertGreaterThanOrEqual(result.meshCount, 0)
        XCTAssertGreaterThan(result.queryTime, 0)
    }
    
    func testQuerySessionWithInvalidURL() async {
        let sessionID = "test-session-123"
        let invalidURL = "not-a-valid-url"
        
        await stagService.querySession(sessionID: sessionID, stagURL: invalidURL)
        
        // Should complete with error
        XCTAssertFalse(stagService.isLoading)
        XCTAssertNotNil(stagService.lastError)
        
        // Result should be empty
        let result = stagService.lastResult!
        XCTAssertEqual(result, QueryResult.empty)
    }
    
    func testQuerySessionWithEmptySessionID() async {
        let emptySessionID = ""
        let stagURL = "http://localhost:8081/query"
        
        await stagService.querySession(sessionID: emptySessionID, stagURL: stagURL)
        
        // Should still work (server might handle empty session ID)
        XCTAssertFalse(stagService.isLoading)
        XCTAssertNotNil(stagService.lastResult)
    }
    
    // MARK: - Loading State Tests
    func testLoadingStateTransition() async {
        let sessionID = "test-session-123"
        let stagURL = "http://localhost:8081/query"
        
        // Start query and immediately check loading state
        Task {
            await stagService.querySession(sessionID: sessionID, stagURL: stagURL)
        }
        
        // Give it a moment to start
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Should be loading initially
        XCTAssertTrue(stagService.isLoading)
        
        // Wait for completion
        var attempts = 0
        while stagService.isLoading && attempts < 50 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            attempts += 1
        }
        
        // Should finish loading
        XCTAssertFalse(stagService.isLoading)
    }
    
    // MARK: - Result Validation Tests
    func testResultStructure() async {
        let sessionID = "test-session-123"
        let stagURL = "http://localhost:8081/query"
        
        await stagService.querySession(sessionID: sessionID, stagURL: stagURL)
        
        guard let result = stagService.lastResult else {
            XCTFail("Expected result to be non-nil")
            return
        }
        
        // Validate anchor structure
        for anchor in result.anchors {
            XCTAssertFalse(anchor.id.isEmpty)
            XCTAssertGreaterThanOrEqual(anchor.frameNumber, 0)
            XCTAssertGreaterThan(anchor.timestamp, 0)
            
            // Position should be reasonable (within a few meters)
            XCTAssertLessThanOrEqual(abs(anchor.position.x), 10.0)
            XCTAssertLessThanOrEqual(abs(anchor.position.y), 10.0)
            XCTAssertLessThanOrEqual(abs(anchor.position.z), 10.0)
        }
        
        // Validate other properties
        XCTAssertGreaterThanOrEqual(result.meshCount, 0)
        XCTAssertGreaterThanOrEqual(result.totalDataSize, 0)
        XCTAssertGreaterThan(result.queryTime, 0)
        XCTAssertLessThan(result.queryTime, 10.0) // Shouldn't take more than 10 seconds
    }
    
    // MARK: - Error Handling Tests
    func testSTAGQueryErrorTypes() {
        let invalidURLError = STAGQueryError.invalidURL
        XCTAssertEqual(invalidURLError.errorDescription, "Invalid STAG URL")
        
        let networkError = STAGQueryError.networkError(NSError(domain: "test", code: 1))
        XCTAssertTrue(networkError.errorDescription?.contains("Network error") ?? false)
        
        let invalidResponseError = STAGQueryError.invalidResponse
        XCTAssertEqual(invalidResponseError.errorDescription, "Invalid response from STAG")
    }
    
    // MARK: - Multiple Query Tests
    func testMultipleConsecutiveQueries() async {
        let sessionID = "test-session-123"
        let stagURL = "http://localhost:8081/query"
        
        // First query
        await stagService.querySession(sessionID: sessionID, stagURL: stagURL)
        let firstResult = stagService.lastResult
        
        // Second query
        await stagService.querySession(sessionID: sessionID + "-2", stagURL: stagURL)
        let secondResult = stagService.lastResult
        
        // Both should complete successfully
        XCTAssertNotNil(firstResult)
        XCTAssertNotNil(secondResult)
        XCTAssertFalse(stagService.isLoading)
        
        // Results might be different (different session IDs)
        // But both should be valid
        XCTAssertGreaterThanOrEqual(firstResult?.anchors.count ?? 0, 0)
        XCTAssertGreaterThanOrEqual(secondResult?.anchors.count ?? 0, 0)
    }
    
    // MARK: - Performance Tests
    func testQueryPerformance() async {
        let sessionID = "test-session-123"
        let stagURL = "http://localhost:8081/query"
        
        let startTime = Date()
        await stagService.querySession(sessionID: sessionID, stagURL: stagURL)
        let endTime = Date()
        
        let actualDuration = endTime.timeIntervalSince(startTime)
        let reportedDuration = stagService.lastResult?.queryTime ?? 0
        
        // Actual duration should be close to reported duration
        XCTAssertLessThan(abs(actualDuration - reportedDuration), 1.0)
        
        // Should complete in reasonable time (mock takes ~2 seconds)
        XCTAssertLessThan(actualDuration, 5.0)
    }
    
    // MARK: - Mock Data Validation Tests
    func testMockDataGeneration() async {
        let sessionID = "test-session-123"
        let stagURL = "http://localhost:8081/query"
        
        await stagService.querySession(sessionID: sessionID, stagURL: stagURL)
        
        guard let result = stagService.lastResult else {
            XCTFail("Expected result to be non-nil")
            return
        }
        
        // Mock should generate reasonable data
        XCTAssertGreaterThanOrEqual(result.anchors.count, 5)
        XCTAssertLessThanOrEqual(result.anchors.count, 20)
        
        XCTAssertGreaterThanOrEqual(result.meshCount, 2)
        XCTAssertLessThanOrEqual(result.meshCount, 8)
        
        XCTAssertGreaterThanOrEqual(result.totalDataSize, 1024*1024) // At least 1MB
        XCTAssertLessThanOrEqual(result.totalDataSize, 10*1024*1024) // At most 10MB
        
        // Anchors should have sequential frame numbers
        let sortedAnchors = result.anchors.sorted { $0.frameNumber < $1.frameNumber }
        for (index, anchor) in sortedAnchors.enumerated() {
            XCTAssertEqual(anchor.frameNumber, index * 3 + 1)
        }
    }
}