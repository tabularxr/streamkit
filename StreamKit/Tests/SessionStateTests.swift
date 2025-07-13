import XCTest
@testable import StreamKit

final class SessionStateTests: XCTestCase {
    
    var sessionState: SessionState!
    
    override func setUp() {
        super.setUp()
        sessionState = SessionState()
    }
    
    override func tearDown() {
        sessionState = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertEqual(sessionState.framesSent, 0)
        XCTAssertEqual(sessionState.meshesSent, 0)
        XCTAssertEqual(sessionState.sessionDuration, 0)
        XCTAssertEqual(sessionState.averageFrameRate, 0)
        XCTAssertEqual(sessionState.averageMeshRate, 0)
    }
    
    // MARK: - Session Management Tests
    
    func testReset() {
        // Increment some counters first
        sessionState.incrementFramesSent()
        sessionState.incrementMeshesSent()
        
        let originalSessionID = sessionState.sessionID
        
        // Reset
        sessionState.reset()
        
        XCTAssertEqual(sessionState.framesSent, 0)
        XCTAssertEqual(sessionState.meshesSent, 0)
        XCTAssertNotEqual(sessionState.sessionID, originalSessionID)
        XCTAssertFalse(sessionState.sessionID.isEmpty)
    }
    
    func testSetSessionID() {
        let newSessionID = "custom-session-id"
        sessionState.setSessionID(newSessionID)
        
        XCTAssertEqual(sessionState.sessionID, newSessionID)
        XCTAssertGreaterThan(sessionState.sessionDuration, 0)
    }
    
    // MARK: - Counter Tests
    
    func testIncrementFramesSent() {
        XCTAssertEqual(sessionState.framesSent, 0)
        
        sessionState.incrementFramesSent()
        XCTAssertEqual(sessionState.framesSent, 1)
        
        sessionState.incrementFramesSent()
        XCTAssertEqual(sessionState.framesSent, 2)
    }
    
    func testIncrementMeshesSent() {
        XCTAssertEqual(sessionState.meshesSent, 0)
        
        sessionState.incrementMeshesSent()
        XCTAssertEqual(sessionState.meshesSent, 1)
        
        sessionState.incrementMeshesSent()
        XCTAssertEqual(sessionState.meshesSent, 2)
    }
    
    // MARK: - Statistics Tests
    
    func testSessionDuration() {
        sessionState.reset()
        
        // Duration should be very small but > 0
        let duration = sessionState.sessionDuration
        XCTAssertGreaterThan(duration, 0)
        XCTAssertLessThan(duration, 1.0) // Should be less than 1 second
    }
    
    func testAverageFrameRate() {
        sessionState.reset()
        
        // Simulate some frame sending
        for _ in 0..<30 {
            sessionState.incrementFramesSent()
        }
        
        // Wait a bit to get meaningful duration
        Thread.sleep(forTimeInterval: 0.1)
        
        let frameRate = sessionState.averageFrameRate
        XCTAssertGreaterThan(frameRate, 0)
        XCTAssertLessThan(frameRate, 1000) // Reasonable upper bound
    }
    
    func testAverageMeshRate() {
        sessionState.reset()
        
        // Simulate some mesh sending
        for _ in 0..<10 {
            sessionState.incrementMeshesSent()
        }
        
        // Wait a bit to get meaningful duration
        Thread.sleep(forTimeInterval: 0.1)
        
        let meshRate = sessionState.averageMeshRate
        XCTAssertGreaterThan(meshRate, 0)
        XCTAssertLessThan(meshRate, 1000) // Reasonable upper bound
    }
    
    // MARK: - Thread Safety Tests
    
    func testThreadSafety() {
        let expectation = XCTestExpectation(description: "Thread safety test")
        expectation.expectedFulfillmentCount = 2
        
        sessionState.reset()
        
        // Concurrent access from multiple threads
        DispatchQueue.global().async {
            for _ in 0..<1000 {
                self.sessionState.incrementFramesSent()
            }
            expectation.fulfill()
        }
        
        DispatchQueue.global().async {
            for _ in 0..<1000 {
                self.sessionState.incrementMeshesSent()
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertEqual(sessionState.framesSent, 1000)
        XCTAssertEqual(sessionState.meshesSent, 1000)
    }
    
    func testConcurrentSessionIDUpdates() {
        let expectation = XCTestExpectation(description: "Concurrent session ID updates")
        expectation.expectedFulfillmentCount = 10
        
        for i in 0..<10 {
            DispatchQueue.global().async {
                self.sessionState.setSessionID("session-\(i)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should have a valid session ID (one of the ones set)
        XCTAssertTrue(sessionState.sessionID.hasPrefix("session-"))
    }
}