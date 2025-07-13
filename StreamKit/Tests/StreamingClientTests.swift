import XCTest
@testable import StreamKit

final class StreamingClientTests: XCTestCase {
    
    var streamingClient: StreamingClient!
    var mockDelegate: MockStreamingClientDelegate!
    
    override func setUp() {
        super.setUp()
        streamingClient = StreamingClient(
            relayURL: "ws://localhost:8080/ws",
            apiKey: "test-api-key"
        )
        mockDelegate = MockStreamingClientDelegate()
        streamingClient.delegate = mockDelegate
    }
    
    override func tearDown() {
        streamingClient?.disconnect()
        streamingClient = nil
        mockDelegate = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(streamingClient.connectionState, .disconnected)
        XCTAssertEqual(streamingClient.connectionUptime, 0)
    }
    
    // MARK: - Connection State Tests
    
    func testInitialConnectionState() {
        XCTAssertEqual(streamingClient.connectionState, .disconnected)
    }
    
    func testConnectionStateTransitions() {
        // Test that connection state changes appropriately
        // Note: These tests would require a mock WebSocket for full testing
        
        XCTAssertEqual(streamingClient.connectionState, .disconnected)
        
        // After calling connect, state should change
        streamingClient.connect()
        // Would need to verify state change with proper mocking
    }
    
    // MARK: - Packet Sending Tests
    
    func testSendPacketWhenDisconnected() {
        // Should buffer packets when disconnected
        let packet = createMockPosePacket()
        
        XCTAssertNoThrow(streamingClient.sendPacket(packet))
        // Packet should be buffered, not sent immediately
    }
    
    func testPacketBuffering() {
        // Send multiple packets while disconnected
        let packets = (0..<5).map { _ in createMockPosePacket() }
        
        for packet in packets {
            streamingClient.sendPacket(packet)
        }
        
        // All packets should be buffered
        // Would need access to internal queue to verify this properly
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidURL() {
        let invalidClient = StreamingClient(
            relayURL: "invalid-url",
            apiKey: "test-key"
        )
        
        let mockDelegate = MockStreamingClientDelegate()
        invalidClient.delegate = mockDelegate
        
        invalidClient.connect()
        
        // Should handle invalid URL gracefully
        XCTAssertEqual(invalidClient.connectionState, .disconnected)
    }
    
    func testDisconnectWhenNotConnected() {
        // Should not crash
        XCTAssertNoThrow(streamingClient.disconnect())
        XCTAssertEqual(streamingClient.connectionState, .disconnected)
    }
    
    // MARK: - Helper Methods
    
    private func createMockPosePacket() -> SpatialPacket {
        let poseData = PosePacketData(
            position: [0, 0, 0],
            rotation: [0, 0, 0, 1]
        )
        
        return SpatialPacket(
            sessionID: "test-session",
            frameNumber: 1,
            type: .pose,
            data: .pose(poseData)
        )
    }
}

// MARK: - Mock Streaming Client Delegate

class MockStreamingClientDelegate: StreamingClientDelegate {
    
    var connectCalled = false
    var disconnectCalled = false
    var errorCalled = false
    
    var lastSessionID: String?
    var lastError: Error?
    
    func streamingClient(_ client: StreamingClient, didConnect sessionID: String) {
        connectCalled = true
        lastSessionID = sessionID
    }
    
    func streamingClient(_ client: StreamingClient, didDisconnect error: Error?) {
        disconnectCalled = true
        lastError = error
    }
    
    func streamingClient(_ client: StreamingClient, didEncounterError error: Error) {
        errorCalled = true
        lastError = error
    }
    
    func reset() {
        connectCalled = false
        disconnectCalled = false
        errorCalled = false
        lastSessionID = nil
        lastError = nil
    }
}