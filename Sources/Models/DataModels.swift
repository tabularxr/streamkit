import Foundation
import ARKit
import simd

// MARK: - Core Data Models

public struct PoseData: Codable, Equatable {
    public let position: SIMD3<Float>
    public let rotation: simd_quatf
    public let timestamp: Date
    
    public init(position: SIMD3<Float>, rotation: simd_quatf, timestamp: Date = Date()) {
        self.position = position
        self.rotation = rotation
        self.timestamp = timestamp
    }
    
    public init(from transform: simd_float4x4, timestamp: Date = Date()) {
        self.position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        self.rotation = simd_quatf(transform)
        self.timestamp = timestamp
    }
    
    private enum CodingKeys: String, CodingKey {
        case position, rotation, timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let posArray = try container.decode([Float].self, forKey: .position)
        position = SIMD3<Float>(posArray[0], posArray[1], posArray[2])
        let rotArray = try container.decode([Float].self, forKey: .rotation)
        rotation = simd_quatf(ix: rotArray[0], iy: rotArray[1], iz: rotArray[2], r: rotArray[3])
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode([position.x, position.y, position.z], forKey: .position)
        try container.encode([rotation.imag.x, rotation.imag.y, rotation.imag.z, rotation.real], forKey: .rotation)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

public struct MeshData: Equatable {
    public let id: UUID
    public let vertices: [SIMD3<Float>]
    public let faces: [UInt32]
    public let normals: [SIMD3<Float>]
    public let timestamp: Date
    
    public init(id: UUID = UUID(), 
                vertices: [SIMD3<Float>], 
                faces: [UInt32], 
                normals: [SIMD3<Float>] = [], 
                timestamp: Date = Date()) {
        self.id = id
        self.vertices = vertices
        self.faces = faces
        self.normals = normals
        self.timestamp = timestamp
    }
    
    public init?(from anchor: ARMeshAnchor) {
        guard let geometry = anchor.geometry else { return nil }
        
        self.id = anchor.identifier
        self.timestamp = Date()
        
        // Extract vertices
        let vertices = geometry.vertices
        let vertexCount = vertices.count
        let vertexBuffer = vertices.buffer.contents().assumingMemoryBound(to: SIMD3<Float>.self)
        self.vertices = Array(UnsafeBufferPointer(start: vertexBuffer, count: vertexCount))
        
        // Extract faces
        let faces = geometry.faces
        let faceCount = faces.count * faces.indexCountPerPrimitive
        let faceBuffer = faces.buffer.contents().assumingMemoryBound(to: UInt32.self)
        self.faces = Array(UnsafeBufferPointer(start: faceBuffer, count: faceCount))
        
        // Extract normals if available
        if let normals = geometry.normals {
            let normalBuffer = normals.buffer.contents().assumingMemoryBound(to: SIMD3<Float>.self)
            self.normals = Array(UnsafeBufferPointer(start: normalBuffer, count: vertexCount))
        } else {
            self.normals = []
        }
    }
}

public struct CompressedMeshData: Codable {
    public let id: String
    public let anchorId: String
    public let vertices: Data
    public let faces: Data
    public let normals: Data?
    public let compressionLevel: Int
    public let timestamp: Date
    public let originalSize: Int
    public let compressedSize: Int
    
    public var compressionRatio: Double {
        guard originalSize > 0 else { return 0 }
        return Double(compressedSize) / Double(originalSize)
    }
}

public enum ConnectionState: String, Codable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed
}

// MARK: - WebSocket Messages

public struct WSMessage: Codable {
    public let type: String
    public let sessionId: String?
    public let data: Data?
    public let timestamp: Int64
    public let traceId: String?
    
    public init(type: String, sessionId: String? = nil, data: Data? = nil, timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000), traceId: String? = nil) {
        self.type = type
        self.sessionId = sessionId
        self.data = data
        self.timestamp = timestamp
        self.traceId = traceId
    }
}

public struct AnchorUpdate: Codable {
    public let id: String
    public let pose: PoseData
    public let metadata: [String: String]?
}

public struct MeshUpdate: Codable {
    public let id: String
    public let anchorId: String
    public let vertices: String // Base64 encoded compressed data
    public let faces: String    // Base64 encoded compressed data
    public let normals: String? // Base64 encoded compressed data
    public let compressionLevel: Int
    public let isDelta: Bool
    public let baseMeshId: String?
}

// MARK: - Session Management

public struct SessionMetrics: Codable {
    public let sessionId: String
    public let startTime: Date
    public var duration: TimeInterval
    public var framesProcessed: Int
    public var meshesProcessed: Int
    public var bytesTransmitted: Int64
    public var compressionRatio: Double
    public var errors: Int
    
    public init(sessionId: String) {
        self.sessionId = sessionId
        self.startTime = Date()
        self.duration = 0
        self.framesProcessed = 0
        self.meshesProcessed = 0
        self.bytesTransmitted = 0
        self.compressionRatio = 1.0
        self.errors = 0
    }
}