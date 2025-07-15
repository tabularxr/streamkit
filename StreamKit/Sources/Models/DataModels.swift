import Foundation
import ARKit
import simd

// MARK: - Public Data Models

public enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

public enum CompressionLevel: Int, CaseIterable {
    case low = 1
    case medium = 5
    case high = 9
    
    var dracoCompressionLevel: Int {
        return self.rawValue
    }
}

public struct SessionMetrics {
    public let sessionID: String
    public let framesSent: Int
    public let meshesSent: Int
    public let compressionRatio: Double
    public let connectionUptime: TimeInterval
    
    public init(sessionID: String, framesSent: Int, meshesSent: Int, compressionRatio: Double, connectionUptime: TimeInterval) {
        self.sessionID = sessionID
        self.framesSent = framesSent
        self.meshesSent = meshesSent
        self.compressionRatio = compressionRatio
        self.connectionUptime = connectionUptime
    }
}

// MARK: - Internal Data Models

struct PoseData: Codable {
    let position: SIMD3<Float>
    let rotation: simd_quatf
    let timestamp: TimeInterval
    
    init(transform: simd_float4x4, timestamp: TimeInterval) {
        self.position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        self.rotation = simd_quatf(transform)
        self.timestamp = timestamp
    }
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case position, rotation, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let positionArray = try container.decode([Float].self, forKey: .position)
        guard positionArray.count == 3 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Position array must have 3 elements"))
        }
        self.position = SIMD3<Float>(positionArray[0], positionArray[1], positionArray[2])
        
        let rotationArray = try container.decode([Float].self, forKey: .rotation)
        guard rotationArray.count == 4 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Rotation array must have 4 elements"))
        }
        self.rotation = simd_quatf(ix: rotationArray[0], iy: rotationArray[1], iz: rotationArray[2], r: rotationArray[3])
        
        self.timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode([position.x, position.y, position.z], forKey: .position)
        try container.encode([rotation.vector.x, rotation.vector.y, rotation.vector.z, rotation.vector.w], forKey: .rotation)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

struct MeshData {
    let anchorID: String
    let vertices: [SIMD3<Float>]
    let faces: [UInt32]
    let normals: [SIMD3<Float>]
    let timestamp: TimeInterval
    
    init(meshAnchor: ARMeshAnchor) {
        self.anchorID = meshAnchor.identifier.uuidString
        self.timestamp = Date().timeIntervalSince1970
        
        let geometry = meshAnchor.geometry
        
        // Extract vertices
        let vertexBuffer = geometry.vertices
        let vertexPointer = vertexBuffer.buffer.contents().assumingMemoryBound(to: SIMD3<Float>.self)
        self.vertices = Array(UnsafeBufferPointer(start: vertexPointer, count: vertexBuffer.count))
        
        // Extract faces
        let faceBuffer = geometry.faces
        let facePointer = faceBuffer.buffer.contents().assumingMemoryBound(to: UInt32.self)
        let faceCount = faceBuffer.count * 3 // Each face has 3 indices
        self.faces = Array(UnsafeBufferPointer(start: facePointer, count: faceCount))
        
        // Extract normals
        let normalBuffer = geometry.normals
        if normalBuffer.count > 0 {
            let normalPointer = normalBuffer.buffer.contents().assumingMemoryBound(to: SIMD3<Float>.self)
            self.normals = Array(UnsafeBufferPointer(start: normalPointer, count: normalBuffer.count))
        } else {
            self.normals = []
        }
    }
}

struct CompressedMeshData {
    let anchorID: String
    let compressedVertices: Data
    let compressedFaces: Data
    let compressedNormals: Data?
    let originalSize: Int
    let compressedSize: Int
    let timestamp: TimeInterval
    
    var compressionRatio: Double {
        guard originalSize > 0 else { return 0.0 }
        return Double(compressedSize) / Double(originalSize)
    }
}

// MARK: - Packet Models

struct SpatialPacket: Codable {
    let sessionID: String
    let eventID: String
    let frameNumber: Int
    let timestamp: Int64
    let type: PacketType
    let data: PacketData
    
    init(sessionID: String, frameNumber: Int, type: PacketType, data: PacketData) {
        self.sessionID = sessionID
        self.eventID = UUID().uuidString
        self.frameNumber = frameNumber
        self.timestamp = Int64(Date().timeIntervalSince1970 * 1000) // Unix ms
        self.type = type
        self.data = data
    }
}

enum PacketType: String, Codable {
    case pose
    case mesh
}

enum PacketData: Codable {
    case pose(PosePacketData)
    case mesh(MeshPacketData)
    
    private enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "pose":
            let poseData = try container.decode(PosePacketData.self, forKey: .data)
            self = .pose(poseData)
        case "mesh":
            let meshData = try container.decode(MeshPacketData.self, forKey: .data)
            self = .mesh(meshData)
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown packet type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .pose(let poseData):
            try container.encode("pose", forKey: .type)
            try container.encode(poseData, forKey: .data)
        case .mesh(let meshData):
            try container.encode("mesh", forKey: .type)
            try container.encode(meshData, forKey: .data)
        }
    }
}

struct PosePacketData: Codable {
    let position: [Float] // [x, y, z]
    let rotation: [Float] // [x, y, z, w] quaternion
    
    init(pose: PoseData) {
        self.position = [pose.position.x, pose.position.y, pose.position.z]
        self.rotation = [pose.rotation.vector.x, pose.rotation.vector.y, pose.rotation.vector.z, pose.rotation.vector.w]
    }
}

struct MeshPacketData: Codable {
    let anchorID: String
    let verticesData: Data
    let facesData: Data
    let normalsData: Data?
    let compressionRatio: Double
    
    init(compressedMesh: CompressedMeshData) {
        self.anchorID = compressedMesh.anchorID
        self.verticesData = compressedMesh.compressedVertices
        self.facesData = compressedMesh.compressedFaces
        self.normalsData = compressedMesh.compressedNormals
        self.compressionRatio = compressedMesh.compressionRatio
    }
}