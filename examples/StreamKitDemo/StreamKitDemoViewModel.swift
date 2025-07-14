import Foundation
import SwiftUI
import ARKit
import StreamKit
import Combine

@available(iOS 16.0, visionOS 1.0, *)
@MainActor
class StreamManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var sessionState: SessionState = .idle
    @Published var metrics = StreamMetrics.empty
    @Published var logs: [LogEntry] = []
    @Published var connectionStatus = ConnectionStatus.disconnected
    @Published var isARKitSupported = false
    @Published var meshBufferStatus: String = "Empty"
    @Published var lastError: Error?
    
    // MARK: - Private Properties
    private var streamKit: StreamKit?
    private var startTime: Date?
    private var frameCount = 0
    private var lastFPSUpdate = Date()
    private var packetsSent = 0
    private var totalDataSent: Int64 = 0
    private var compressionRatios: [Double] = []
    private var errorCount = 0
    
    private var metricsTimer: Timer?
    private let logQueue = DispatchQueue(label: "com.tabular.streamkit.logs")
    
    override init() {
        super.init()
        checkARKitSupport()
        setupMetricsTimer()
    }
    
    deinit {
        metricsTimer?.invalidate()
        streamKit?.stopStreaming()
    }
    
    // MARK: - Public Methods
    func configure(with config: DemoConfiguration) {
        guard !config.relayURL.isEmpty && !config.apiKey.isEmpty else {
            addLog(.error, "Configuration incomplete: Missing Relay URL or API Key")
            return
        }
        
        streamKit = StreamKit(
            relayURL: config.relayURL,
            apiKey: config.apiKey
        )
        
        streamKit?.delegate = self
        streamKit?.configure(
            compression: mapCompressionLevel(config.compressionLevel),
            bufferSize: 100
        )
        
        addLog(.info, "StreamKit configured with URL: \(config.relayURL)")
    }
    
    func startStreaming() {
        guard let streamKit = streamKit else {
            addLog(.error, "StreamKit not configured")
            return
        }
        
        guard isARKitSupported else {
            addLog(.error, "ARKit not supported on this device")
            return
        }
        
        do {
            sessionState = .connecting
            try streamKit.startStreaming()
            startTime = Date()
            frameCount = 0
            packetsSent = 0
            totalDataSent = 0
            compressionRatios.removeAll()
            errorCount = 0
            lastError = nil
            
            addLog(.info, "Starting streaming session...")
        } catch {
            sessionState = .error(error.localizedDescription)
            lastError = error
            addLog(.error, "Failed to start streaming: \(error.localizedDescription)")
        }
    }
    
    func stopStreaming() {
        streamKit?.stopStreaming()
        sessionState = .idle
        startTime = nil
        lastError = nil
        
        addLog(.info, "Streaming session stopped")
        logSessionSummary()
    }
    
    func pauseStreaming() {
        streamKit?.pauseStreaming()
        sessionState = .paused
        addLog(.info, "Streaming paused")
    }
    
    func resumeStreaming() {
        streamKit?.resumeStreaming()
        sessionState = .streaming
        addLog(.info, "Streaming resumed")
    }
    
    func manualMeshCapture() {
        // Force send current mesh anchor
        addLog(.mesh, "Manual mesh capture triggered")
    }
    
    func clearLogs() {
        logQueue.async {
            DispatchQueue.main.async {
                self.logs.removeAll()
            }
        }
    }
    
    // MARK: - Private Methods
    private func checkARKitSupport() {
        isARKitSupported = ARWorldTrackingConfiguration.isSupported
        
        if !isARKitSupported {
            addLog(.error, "ARKit not supported on this device")
        } else {
            addLog(.info, "ARKit support confirmed")
        }
    }
    
    private func setupMetricsTimer() {
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
    }
    
    private func updateMetrics() {
        guard let startTime = startTime else {
            metrics = StreamMetrics.empty
            return
        }
        
        let uptime = Date().timeIntervalSince(startTime)
        let fps = calculateFPS()
        let compressionRatio = compressionRatios.isEmpty ? 0 : compressionRatios.reduce(0, +) / Double(compressionRatios.count)
        let bandwidth = calculateBandwidth(uptime: uptime)
        
        metrics = StreamMetrics(
            fps: fps,
            packetsSent: packetsSent,
            compressionRatio: compressionRatio,
            bandwidth: bandwidth,
            sessionID: streamKit?.currentSessionID,
            uptime: uptime,
            errorCount: errorCount
        )
    }
    
    private func calculateFPS() -> Double {
        let now = Date()
        let timeDiff = now.timeIntervalSince(lastFPSUpdate)
        
        if timeDiff >= 1.0 {
            let fps = Double(frameCount) / timeDiff
            frameCount = 0
            lastFPSUpdate = now
            return fps
        }
        
        return metrics.fps
    }
    
    private func calculateBandwidth(uptime: TimeInterval) -> Double {
        guard uptime > 0 else { return 0 }
        return Double(totalDataSent) / uptime / 1024 // KB/s
    }
    
    private func addLog(_ type: LogEntry.LogType, _ message: String, details: String? = nil) {
        let entry = LogEntry(
            timestamp: Date(),
            type: type,
            message: message,
            details: details
        )
        
        logQueue.async {
            DispatchQueue.main.async {
                self.logs.append(entry)
                
                // Keep only last 1000 entries
                if self.logs.count > 1000 {
                    self.logs.removeFirst(self.logs.count - 1000)
                }
            }
        }
    }
    
    private func mapCompressionLevel(_ level: CompressionLevel) -> StreamKit.CompressionLevel {
        switch level {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
    
    private func logSessionSummary() {
        guard let startTime = startTime else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        let avgFPS = metrics.fps
        let totalMB = Double(totalDataSent) / (1024 * 1024)
        
        addLog(.info, """
            Session Summary:
            Duration: \(String(format: "%.1f", duration))s
            Avg FPS: \(String(format: "%.1f", avgFPS))
            Packets: \(packetsSent)
            Data: \(String(format: "%.2f", totalMB))MB
            Errors: \(errorCount)
            """)
    }
}

// MARK: - StreamKitDelegate
extension StreamManager: StreamKitDelegate {
    func streamKit(_ streamKit: StreamKit, didConnect sessionID: String) {
        sessionState = .streaming
        connectionStatus = ConnectionStatus(
            isConnected: true,
            lastConnected: Date(),
            reconnectAttempts: 0,
            latency: nil
        )
        
        addLog(.network, "Connected to Relay server", details: "Session ID: \(sessionID)")
    }
    
    func streamKit(_ streamKit: StreamKit, didDisconnect error: Error?) {
        sessionState = .disconnected
        connectionStatus = ConnectionStatus(
            isConnected: false,
            lastConnected: connectionStatus.lastConnected,
            reconnectAttempts: connectionStatus.reconnectAttempts + 1,
            latency: nil
        )
        
        if let error = error {
            lastError = error
            addLog(.network, "Disconnected from server", details: error.localizedDescription)
        } else {
            addLog(.network, "Disconnected from server")
        }
    }
    
    func streamKit(_ streamKit: StreamKit, didStartStreaming sessionID: String) {
        sessionState = .streaming
        addLog(.info, "Streaming started", details: "Session: \(sessionID)")
    }
    
    func streamKit(_ streamKit: StreamKit, didStopStreaming sessionID: String) {
        sessionState = .idle
        addLog(.info, "Streaming stopped", details: "Session: \(sessionID)")
    }
    
    func streamKit(_ streamKit: StreamKit, didSendFrame frameNumber: Int) {
        frameCount += 1
        packetsSent += 1
        
        // Estimate 32 bytes per pose packet
        totalDataSent += 32
        
        if frameNumber % 30 == 0 { // Log every 30 frames
            addLog(.pose, "Pose sent: Frame \(frameNumber)")
        }
    }
    
    func streamKit(_ streamKit: StreamKit, didEncounterError error: StreamKitError) {
        errorCount += 1
        lastError = error
        
        switch error {
        case .alreadyStreaming:
            addLog(.error, "Already streaming")
        case .arNotSupported:
            addLog(.error, "ARKit not supported")
        case .networkError(let networkError):
            addLog(.network, "Network error", details: networkError.localizedDescription)
        case .compressionError(let compressionError):
            addLog(.compression, "Compression error", details: compressionError.localizedDescription)
        case .authenticationFailed:
            addLog(.error, "Authentication failed - check API key")
        case .arSessionError(let arError):
            addLog(.error, "ARKit session error", details: arError.localizedDescription)
        }
    }
    
    // Additional delegate methods for mesh handling
    func streamKit(_ streamKit: StreamKit, didCompressMesh originalSize: Int, compressedSize: Int) {
        let ratio = Double(compressedSize) / Double(originalSize)
        compressionRatios.append(1.0 - ratio) // Store compression ratio as reduction percentage
        
        totalDataSent += Int64(compressedSize)
        
        let compressionPercent = (1.0 - ratio) * 100
        addLog(.compression, 
               "Mesh compressed: \(formatBytes(originalSize)) → \(formatBytes(compressedSize))",
               details: "\(String(format: "%.1f", compressionPercent))% reduction")
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Data Models
struct StreamMetrics {
    let fps: Double
    let packetsSent: Int
    let compressionRatio: Double
    let bandwidth: Double
    let sessionID: String?
    let uptime: TimeInterval
    let errorCount: Int
    
    static let empty = StreamMetrics(
        fps: 0,
        packetsSent: 0,
        compressionRatio: 0,
        bandwidth: 0,
        sessionID: nil,
        uptime: 0,
        errorCount: 0
    )
}

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let type: LogType
    let message: String
    let details: String?
    
    enum LogType: String, CaseIterable {
        case pose = "Pose"
        case mesh = "Mesh"
        case error = "Error"
        case info = "Info"
        case warning = "Warning"
        case network = "Network"
        case compression = "Compression"
        
        var color: String {
            switch self {
            case .pose: return "blue"
            case .mesh: return "green"
            case .error: return "red"
            case .info: return "gray"
            case .warning: return "orange"
            case .network: return "purple"
            case .compression: return "cyan"
            }
        }
        
        var icon: String {
            switch self {
            case .pose: return "location.fill"
            case .mesh: return "cube.fill"
            case .error: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .network: return "network"
            case .compression: return "archivebox.fill"
            }
        }
    }
}

enum SessionState {
    case idle
    case connecting
    case streaming
    case paused
    case disconnected
    case error(String)
    
    var displayText: String {
        switch self {
        case .idle: return "Ready to start"
        case .connecting: return "Connecting..."
        case .streaming: return "Streaming"
        case .paused: return "Paused"
        case .disconnected: return "Disconnected"
        case .error(let message): return "Error: \(message)"
        }
    }
    
    var color: String {
        switch self {
        case .idle: return "gray"
        case .connecting: return "yellow"
        case .streaming: return "green"
        case .paused: return "orange"
        case .disconnected: return "red"
        case .error: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .idle: return "play.circle"
        case .connecting: return "dot.radiowaves.left.and.right"
        case .streaming: return "record.circle"
        case .paused: return "pause.circle"
        case .disconnected: return "wifi.slash"
        case .error: return "exclamationmark.triangle"
        }
    }
}

struct ConnectionStatus {
    let isConnected: Bool
    let lastConnected: Date?
    let reconnectAttempts: Int
    let latency: TimeInterval?
    
    static let disconnected = ConnectionStatus(
        isConnected: false,
        lastConnected: nil,
        reconnectAttempts: 0,
        latency: nil
    )
}

// MARK: - StreamKit Extensions
extension StreamKit {
    enum CompressionLevel {
        case low
        case medium
        case high
    }
}