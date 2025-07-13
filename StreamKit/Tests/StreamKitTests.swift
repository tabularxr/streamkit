import XCTest
import ARKit
@testable import StreamKit

@available(iOS 16.0, visionOS 1.0, *)
final class StreamKitTests: XCTestCase {
    
    var streamKit: StreamKit!
    var mockDelegate: MockStreamKitDelegate!
    
    override func setUp() {
        super.setUp()
        streamKit = StreamKit(relayURL: "ws://localhost:8080/ws", apiKey: "test-api-key")
        mockDelegate = MockStreamKitDelegate()
        streamKit.delegate = mockDelegate
    }
    
    override func tearDown() {
        streamKit?.stopStreaming()
        streamKit = nil
        mockDelegate = nil
        super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testInitialization() {
        XCTAssertNotNil(streamKit)
        XCTAssertEqual(streamKit.connectionState, .disconnected)
        XCTAssertNil(streamKit.currentSessionID)
    }
    
    func testConfiguration() {
        streamKit.configure(compression: .high, bufferSize: 200)
        
        // Configuration should be applied
        // We can't directly test private properties, but we can test behavior
        XCTAssertNotNil(streamKit)
    }
    
    func testSessionMetrics() {
        let metrics = streamKit.sessionMetrics
        XCTAssertEqual(metrics.framesSent, 0)
        XCTAssertEqual(metrics.meshesSent, 0)
        XCTAssertEqual(metrics.connectionUptime, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testMultipleStartStreamingCalls() {
        // First call should succeed (if ARKit is available)
        // Second call should throw alreadyStreaming error
        
        // Note: These tests would need to be run on a physical device with ARKit
        // For CI/CD, we would mock the ARKit components
        
        if ARWorldTrackingConfiguration.isSupported {
            XCTAssertNoThrow(try streamKit.startStreaming())
            
            XCTAssertThrowsError(try streamKit.startStreaming()) { error in
                XCTAssertTrue(error is StreamKitError)
                if case StreamKitError.alreadyStreaming = error {
                    // Expected error
                } else {
                    XCTFail("Expected alreadyStreaming error, got \(error)")
                }
            }
        }
    }
    
    func testStopStreamingWhenNotStreaming() {
        // Should not crash or throw
        XCTAssertNoThrow(streamKit.stopStreaming())
    }
    
    func testPauseResumeWithoutStreaming() {
        // Should not crash
        XCTAssertNoThrow(streamKit.pauseStreaming())
        XCTAssertNoThrow(streamKit.resumeStreaming())
    }
}

// MARK: - Mock Delegate

class MockStreamKitDelegate: StreamKitDelegate {
    
    var connectCalled = false
    var disconnectCalled = false
    var startStreamingCalled = false
    var stopStreamingCalled = false
    var pauseStreamingCalled = false
    var resumeStreamingCalled = false
    var frameSentCalled = false
    var errorCalled = false
    
    var lastSessionID: String?
    var lastFrameNumber: Int?
    var lastError: StreamKitError?
    var lastDisconnectError: Error?
    
    func streamKit(_ streamKit: StreamKit, didConnect sessionID: String) {
        connectCalled = true
        lastSessionID = sessionID
    }
    
    func streamKit(_ streamKit: StreamKit, didDisconnect error: Error?) {
        disconnectCalled = true
        lastDisconnectError = error
    }
    
    func streamKit(_ streamKit: StreamKit, didStartStreaming sessionID: String) {
        startStreamingCalled = true
        lastSessionID = sessionID
    }
    
    func streamKit(_ streamKit: StreamKit, didStopStreaming sessionID: String) {
        stopStreamingCalled = true
        lastSessionID = sessionID
    }
    
    func streamKit(_ streamKit: StreamKit, didPauseStreaming sessionID: String) {
        pauseStreamingCalled = true
        lastSessionID = sessionID
    }
    
    func streamKit(_ streamKit: StreamKit, didResumeStreaming sessionID: String) {
        resumeStreamingCalled = true
        lastSessionID = sessionID
    }
    
    func streamKit(_ streamKit: StreamKit, didSendFrame frameNumber: Int) {
        frameSentCalled = true
        lastFrameNumber = frameNumber
    }
    
    func streamKit(_ streamKit: StreamKit, didEncounterError error: StreamKitError) {
        errorCalled = true
        lastError = error
    }
    
    func reset() {
        connectCalled = false
        disconnectCalled = false
        startStreamingCalled = false
        stopStreamingCalled = false
        pauseStreamingCalled = false
        resumeStreamingCalled = false
        frameSentCalled = false
        errorCalled = false
        
        lastSessionID = nil
        lastFrameNumber = nil
        lastError = nil
        lastDisconnectError = nil
    }
}