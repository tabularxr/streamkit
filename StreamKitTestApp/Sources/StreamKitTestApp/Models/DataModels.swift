import Foundation
import StreamKit

// MARK: - StreamMetrics
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

// MARK: - LogEntry
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

// MARK: - QueryResult
struct QueryResult {
    let anchors: [PoseAnchor]
    let meshCount: Int
    let decompressedSizes: [String: Int] // mesh_id -> size in bytes
    let totalDataSize: Int
    let queryTime: TimeInterval
    
    static let empty = QueryResult(
        anchors: [],
        meshCount: 0,
        decompressedSizes: [:],
        totalDataSize: 0,
        queryTime: 0
    )
}

struct PoseAnchor: Identifiable, Codable {
    let id: String
    let position: SIMD3<Float>
    let rotation: simd_quatf
    let timestamp: TimeInterval
    let frameNumber: Int
    
    var formattedPosition: String {
        return String(format: "(%.2f, %.2f, %.2f)", position.x, position.y, position.z)
    }
}

// MARK: - App Configuration
struct AppConfiguration {
    var relayURL: String
    var apiKey: String
    var compressionLevel: CompressionLevel
    var autoReconnect: Bool
    var verboseLogging: Bool
    var stagQueryURL: String
    
    static let `default` = AppConfiguration(
        relayURL: "ws://localhost:8080/ws/streamkit",
        apiKey: "",
        compressionLevel: .medium,
        autoReconnect: true,
        verboseLogging: false,
        stagQueryURL: "http://localhost:8081/query"
    )
}

enum CompressionLevel: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var description: String {
        switch self {
        case .low: return "Faster compression, larger files"
        case .medium: return "Balanced performance and size"
        case .high: return "Best compression, slower processing"
        }
    }
}

// MARK: - Session State
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

// MARK: - Connection Status
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