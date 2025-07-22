import XCTest
@testable import StreamKit

final class StreamKitTests: XCTestCase {
    
    var streamKit: StreamKit!
    
    override func setUp() {
        super.setUp()
        streamKit = StreamKit(serverURL: "http://localhost:8080", apiKey: "test-key")
    }
    
    override func tearDown() {
        streamKit = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertNotNil(streamKit)
        XCTAssertFalse(streamKit.isStreaming)
        XCTAssertNil(streamKit.sessionId)
    }
    
    func testCompressionLevel() {
        streamKit.compressionLevel = .high
        XCTAssertEqual(streamKit.compressionLevel, .high)
    }
    
    func testMeshDiffingToggle() {
        streamKit.enableMeshDiffing = false
        XCTAssertFalse(streamKit.enableMeshDiffing)
        
        streamKit.enableMeshDiffing = true
        XCTAssertTrue(streamKit.enableMeshDiffing)
    }
}

// MARK: - Mock Delegate

class MockStreamKitDelegate: StreamKitDelegate {
    var didStartStreaming = false
    var didStopStreaming = false
    var didConnect = false
    var didDisconnect = false
    var errors: [Error] = []
    var serverErrors: [String] = []
    
    func streamKitDidStartStreaming(_ streamKit: StreamKit) {
        didStartStreaming = true
    }
    
    func streamKitDidStopStreaming(_ streamKit: StreamKit) {
        didStopStreaming = true
    }
    
    func streamKitDidPauseStreaming(_ streamKit: StreamKit) {}
    func streamKitDidResumeStreaming(_ streamKit: StreamKit) {}
    
    func streamKitDidConnect(_ streamKit: StreamKit) {
        didConnect = true
    }
    
    func streamKitDidDisconnect(_ streamKit: StreamKit) {
        didDisconnect = true
    }
    
    func streamKit(_ streamKit: StreamKit, didEncounterError error: Error) {
        errors.append(error)
    }
    
    func streamKit(_ streamKit: StreamKit, didReceiveServerError error: String) {
        serverErrors.append(error)
    }
}