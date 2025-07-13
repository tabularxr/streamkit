import XCTest
@testable import StreamKitTestApp

final class StreamKitTestAppTests: XCTestCase {
    
    // MARK: - Data Model Tests
    func testStreamMetricsInitialization() {
        let metrics = StreamMetrics(
            fps: 30.0,
            packetsSent: 100,
            compressionRatio: 0.85,
            bandwidth: 1024.5,
            sessionID: "test-session",
            uptime: 60.0,
            errorCount: 2
        )
        
        XCTAssertEqual(metrics.fps, 30.0)
        XCTAssertEqual(metrics.packetsSent, 100)
        XCTAssertEqual(metrics.compressionRatio, 0.85)
        XCTAssertEqual(metrics.bandwidth, 1024.5)
        XCTAssertEqual(metrics.sessionID, "test-session")
        XCTAssertEqual(metrics.uptime, 60.0)
        XCTAssertEqual(metrics.errorCount, 2)
    }
    
    func testLogEntryCreation() {
        let entry = LogEntry(
            timestamp: Date(),
            type: .pose,
            message: "Test message",
            details: "Test details"
        )
        
        XCTAssertEqual(entry.type, .pose)
        XCTAssertEqual(entry.message, "Test message")
        XCTAssertEqual(entry.details, "Test details")
        XCTAssertNotNil(entry.id)
    }
    
    func testLogTypeProperties() {
        let poseType = LogEntry.LogType.pose
        XCTAssertEqual(poseType.color, "blue")
        XCTAssertEqual(poseType.icon, "location.fill")
        
        let errorType = LogEntry.LogType.error
        XCTAssertEqual(errorType.color, "red")
        XCTAssertEqual(errorType.icon, "exclamationmark.triangle.fill")
    }
    
    func testPoseAnchorFormatting() {
        let anchor = PoseAnchor(
            id: "test-id",
            position: SIMD3<Float>(1.5, 2.0, -0.5),
            rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
            timestamp: Date().timeIntervalSince1970,
            frameNumber: 42
        )
        
        XCTAssertEqual(anchor.formattedPosition, "(1.50, 2.00, -0.50)")
        XCTAssertEqual(anchor.frameNumber, 42)
    }
    
    // MARK: - App Configuration Tests
    func testAppConfigurationDefault() {
        let config = AppConfiguration.default
        
        XCTAssertEqual(config.relayURL, "ws://localhost:8080/ws/streamkit")
        XCTAssertEqual(config.apiKey, "")
        XCTAssertEqual(config.compressionLevel, .medium)
        XCTAssertTrue(config.autoReconnect)
        XCTAssertFalse(config.verboseLogging)
        XCTAssertEqual(config.stagQueryURL, "http://localhost:8081/query")
    }
    
    func testCompressionLevelDescriptions() {
        XCTAssertEqual(CompressionLevel.low.description, "Faster compression, larger files")
        XCTAssertEqual(CompressionLevel.medium.description, "Balanced performance and size")
        XCTAssertEqual(CompressionLevel.high.description, "Best compression, slower processing")
    }
    
    // MARK: - Session State Tests
    func testSessionStateDisplayText() {
        XCTAssertEqual(SessionState.idle.displayText, "Ready to start")
        XCTAssertEqual(SessionState.connecting.displayText, "Connecting...")
        XCTAssertEqual(SessionState.streaming.displayText, "Streaming")
        XCTAssertEqual(SessionState.paused.displayText, "Paused")
        XCTAssertEqual(SessionState.disconnected.displayText, "Disconnected")
        XCTAssertEqual(SessionState.error("Test error").displayText, "Error: Test error")
    }
    
    func testSessionStateColors() {
        XCTAssertEqual(SessionState.idle.color, "gray")
        XCTAssertEqual(SessionState.connecting.color, "yellow")
        XCTAssertEqual(SessionState.streaming.color, "green")
        XCTAssertEqual(SessionState.paused.color, "orange")
        XCTAssertEqual(SessionState.disconnected.color, "red")
        XCTAssertEqual(SessionState.error("Test").color, "red")
    }
    
    func testSessionStateIcons() {
        XCTAssertEqual(SessionState.idle.icon, "play.circle")
        XCTAssertEqual(SessionState.connecting.icon, "dot.radiowaves.left.and.right")
        XCTAssertEqual(SessionState.streaming.icon, "record.circle")
        XCTAssertEqual(SessionState.paused.icon, "pause.circle")
        XCTAssertEqual(SessionState.disconnected.icon, "wifi.slash")
        XCTAssertEqual(SessionState.error("Test").icon, "exclamationmark.triangle")
    }
    
    // MARK: - Error Handling Tests
    func testAppErrorCreation() {
        let error = AppError.networkError(
            "Connection failed",
            recovery: .retry,
            context: "test-context"
        )
        
        XCTAssertEqual(error.title, "Network Error")
        XCTAssertEqual(error.message, "Connection failed")
        XCTAssertEqual(error.recovery, .retry)
        XCTAssertFalse(error.isCritical)
        XCTAssertEqual(error.context, "test-context")
    }
    
    func testRecoveryActionProperties() {
        let retryAction = RecoveryAction.retry
        XCTAssertEqual(retryAction.icon, "arrow.clockwise")
        XCTAssertEqual(retryAction.description, "Try the operation again")
        
        let configureAction = RecoveryAction.configure
        XCTAssertEqual(configureAction.icon, "gear")
        XCTAssertEqual(configureAction.description, "Review app configuration")
    }
    
    // MARK: - Query Result Tests
    func testQueryResultEmpty() {
        let result = QueryResult.empty
        
        XCTAssertTrue(result.anchors.isEmpty)
        XCTAssertEqual(result.meshCount, 0)
        XCTAssertTrue(result.decompressedSizes.isEmpty)
        XCTAssertEqual(result.totalDataSize, 0)
        XCTAssertEqual(result.queryTime, 0)
    }
    
    func testQueryResultWithData() {
        let anchors = [
            PoseAnchor(
                id: "anchor1",
                position: SIMD3<Float>(0, 0, 0),
                rotation: simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
                timestamp: Date().timeIntervalSince1970,
                frameNumber: 1
            )
        ]
        
        let result = QueryResult(
            anchors: anchors,
            meshCount: 5,
            decompressedSizes: ["mesh1": 1024],
            totalDataSize: 2048,
            queryTime: 1.5
        )
        
        XCTAssertEqual(result.anchors.count, 1)
        XCTAssertEqual(result.meshCount, 5)
        XCTAssertEqual(result.decompressedSizes["mesh1"], 1024)
        XCTAssertEqual(result.totalDataSize, 2048)
        XCTAssertEqual(result.queryTime, 1.5)
    }
    
    // MARK: - Connection Status Tests
    func testConnectionStatusDisconnected() {
        let status = ConnectionStatus.disconnected
        
        XCTAssertFalse(status.isConnected)
        XCTAssertNil(status.lastConnected)
        XCTAssertEqual(status.reconnectAttempts, 0)
        XCTAssertNil(status.latency)
    }
    
    func testConnectionStatusConnected() {
        let now = Date()
        let status = ConnectionStatus(
            isConnected: true,
            lastConnected: now,
            reconnectAttempts: 2,
            latency: 0.1
        )
        
        XCTAssertTrue(status.isConnected)
        XCTAssertEqual(status.lastConnected, now)
        XCTAssertEqual(status.reconnectAttempts, 2)
        XCTAssertEqual(status.latency, 0.1)
    }
}