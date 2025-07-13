import XCTest
@testable import StreamKitTestApp

@MainActor
final class StreamManagerTests: XCTestCase {
    var streamManager: StreamManager!
    
    override func setUp() async throws {
        streamManager = StreamManager()
    }
    
    override func tearDown() async throws {
        streamManager = nil
    }
    
    // MARK: - Initialization Tests
    func testStreamManagerInitialization() {
        XCTAssertEqual(streamManager.sessionState, .idle)
        XCTAssertEqual(streamManager.metrics, StreamMetrics.empty)
        XCTAssertTrue(streamManager.logs.isEmpty)
        XCTAssertEqual(streamManager.connectionStatus, ConnectionStatus.disconnected)
        XCTAssertEqual(streamManager.meshBufferStatus, "Empty")
    }
    
    // MARK: - Configuration Tests
    func testConfigurationWithValidSettings() {
        let config = AppConfiguration(
            relayURL: "ws://test.example.com/ws",
            apiKey: "test-api-key",
            compressionLevel: .high,
            autoReconnect: true,
            verboseLogging: true,
            stagQueryURL: "http://test.example.com/query"
        )
        
        streamManager.configure(with: config)
        
        // Should have added a log entry
        XCTAssertFalse(streamManager.logs.isEmpty)
        let lastLog = streamManager.logs.last
        XCTAssertEqual(lastLog?.type, .info)
        XCTAssertTrue(lastLog?.message.contains("configured") ?? false)
    }
    
    func testConfigurationWithEmptySettings() {
        let config = AppConfiguration(
            relayURL: "",
            apiKey: "",
            compressionLevel: .medium,
            autoReconnect: true,
            verboseLogging: false,
            stagQueryURL: ""
        )
        
        streamManager.configure(with: config)
        
        // Should have added an error log
        XCTAssertFalse(streamManager.logs.isEmpty)
        let lastLog = streamManager.logs.last
        XCTAssertEqual(lastLog?.type, .error)
        XCTAssertTrue(lastLog?.message.contains("incomplete") ?? false)
    }
    
    // MARK: - Logging Tests
    func testLogManagement() {
        // Add some logs
        for i in 0..<5 {
            streamManager.addTestLog(.info, "Test message \(i)")
        }
        
        XCTAssertEqual(streamManager.logs.count, 5)
        
        // Clear logs
        streamManager.clearLogs()
        XCTAssertTrue(streamManager.logs.isEmpty)
    }
    
    func testLogFiltering() {
        // Add different types of logs
        streamManager.addTestLog(.pose, "Pose message")
        streamManager.addTestLog(.mesh, "Mesh message")
        streamManager.addTestLog(.error, "Error message")
        streamManager.addTestLog(.info, "Info message")
        
        let poseLogs = streamManager.logs.filter { $0.type == .pose }
        let errorLogs = streamManager.logs.filter { $0.type == .error }
        
        XCTAssertEqual(poseLogs.count, 1)
        XCTAssertEqual(errorLogs.count, 1)
        XCTAssertEqual(poseLogs.first?.message, "Pose message")
        XCTAssertEqual(errorLogs.first?.message, "Error message")
    }
    
    func testLogRotation() {
        // Add more than 1000 logs to test rotation
        for i in 0..<1005 {
            streamManager.addTestLog(.info, "Test message \(i)")
        }
        
        // Should keep only the last 1000
        XCTAssertEqual(streamManager.logs.count, 1000)
        
        // Should have the most recent logs
        let firstLog = streamManager.logs.first
        XCTAssertTrue(firstLog?.message.contains("1000") ?? false)
    }
    
    // MARK: - Metrics Tests
    func testMetricsCalculation() {
        // Start a session
        streamManager.startTestSession()
        
        // Simulate some activity
        streamManager.simulateFrameProcessing(count: 30)
        streamManager.simulateDataTransfer(bytes: 1024)
        
        let metrics = streamManager.metrics
        XCTAssertGreaterThan(metrics.uptime, 0)
        XCTAssertGreaterThan(metrics.packetsSent, 0)
    }
    
    // MARK: - State Management Tests
    func testSessionStateTransitions() {
        // Initial state
        XCTAssertEqual(streamManager.sessionState, .idle)
        
        // Start streaming (without StreamKit configured)
        streamManager.startStreaming()
        
        // Should log an error and remain idle
        XCTAssertEqual(streamManager.sessionState, .idle)
        XCTAssertFalse(streamManager.logs.isEmpty)
        
        let errorLog = streamManager.logs.last
        XCTAssertEqual(errorLog?.type, .error)
    }
    
    func testPauseResumeLogic() {
        streamManager.sessionState = .streaming
        
        streamManager.pauseStreaming()
        XCTAssertEqual(streamManager.sessionState, .paused)
        
        streamManager.resumeStreaming()
        XCTAssertEqual(streamManager.sessionState, .streaming)
    }
    
    // MARK: - Error Handling Tests
    func testErrorCounting() {
        let initialErrorCount = streamManager.metrics.errorCount
        
        // Simulate errors
        streamManager.simulateError(.networkError("Test error"))
        streamManager.simulateError(.compressionError("Compression failed"))
        
        XCTAssertEqual(streamManager.metrics.errorCount, initialErrorCount + 2)
    }
    
    // MARK: - Performance Tests
    func testMemoryUsage() {
        let initialLogCount = streamManager.logs.count
        
        // Add many logs quickly
        for i in 0..<100 {
            streamManager.addTestLog(.info, "Stress test \(i)")
        }
        
        // Should handle rapid log addition without issues
        XCTAssertEqual(streamManager.logs.count, initialLogCount + 100)
    }
    
    func testConcurrentAccess() async {
        // Test thread safety by accessing logs from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask { [weak self] in
                    await self?.streamManager.addTestLog(.info, "Concurrent log \(i)")
                }
            }
        }
        
        // Should have all logs without crashes
        let concurrentLogs = streamManager.logs.filter { $0.message.contains("Concurrent") }
        XCTAssertEqual(concurrentLogs.count, 10)
    }
}

// MARK: - Test Helpers
extension StreamManager {
    func addTestLog(_ type: LogEntry.LogType, _ message: String, details: String? = nil) {
        let entry = LogEntry(
            timestamp: Date(),
            type: type,
            message: message,
            details: details
        )
        logs.append(entry)
    }
    
    func startTestSession() {
        // Simulate starting a session without actual StreamKit
        sessionState = .streaming
        // Set a mock start time for metrics calculation
    }
    
    func simulateFrameProcessing(count: Int) {
        // Simulate processing frames for metrics
        for _ in 0..<count {
            addTestLog(.pose, "Frame processed")
        }
    }
    
    func simulateDataTransfer(bytes: Int) {
        // Simulate data transfer for bandwidth calculation
        addTestLog(.network, "Data transferred: \(bytes) bytes")
    }
    
    func simulateError(_ error: AppError) {
        addTestLog(.error, error.message)
    }
}