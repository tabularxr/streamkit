import Foundation

class PacketBuilder {
    
    // MARK: - Properties
    
    private let jsonEncoder: JSONEncoder
    
    // MARK: - Initialization
    
    init() {
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .millisecondsSince1970
    }
    
    // MARK: - Packet Building
    
    func buildPosePacket(sessionID: String, frameNumber: Int, pose: PoseData) -> SpatialPacket {
        let posePacketData = PosePacketData(pose: pose)
        let packetData = PacketData.pose(posePacketData)
        
        return SpatialPacket(
            sessionID: sessionID,
            frameNumber: frameNumber,
            type: .pose,
            data: packetData
        )
    }
    
    func buildMeshPacket(sessionID: String, frameNumber: Int, mesh: CompressedMeshData) -> SpatialPacket {
        let meshPacketData = MeshPacketData(compressedMesh: mesh)
        let packetData = PacketData.mesh(meshPacketData)
        
        return SpatialPacket(
            sessionID: sessionID,
            frameNumber: frameNumber,
            type: .mesh,
            data: packetData
        )
    }
    
    // MARK: - Serialization Helpers
    
    func serializePacket(_ packet: SpatialPacket) throws -> Data {
        return try jsonEncoder.encode(packet)
    }
    
    func validatePacket(_ packet: SpatialPacket) -> Bool {
        // Basic validation
        guard !packet.sessionID.isEmpty,
              packet.frameNumber >= 0,
              packet.timestamp > 0 else {
            return false
        }
        
        // Type-specific validation
        switch packet.data {
        case .pose(let poseData):
            return validatePoseData(poseData)
        case .mesh(let meshData):
            return validateMeshData(meshData)
        }
    }
    
    // MARK: - Private Validation
    
    private func validatePoseData(_ poseData: PosePacketData) -> Bool {
        // Validate position (finite values)
        guard poseData.position.allSatisfy({ $0.isFinite }) else {
            return false
        }
        
        // Validate quaternion (4 components, normalized)
        guard poseData.rotation.count == 4,
              poseData.rotation.allSatisfy({ $0.isFinite }) else {
            return false
        }
        
        // Check quaternion magnitude (should be close to 1.0)
        let magnitude = sqrt(poseData.rotation.map { $0 * $0 }.reduce(0, +))
        return abs(magnitude - 1.0) < 0.1
    }
    
    private func validateMeshData(_ meshData: MeshPacketData) -> Bool {
        // Validate anchor ID
        guard !meshData.anchorID.isEmpty else {
            return false
        }
        
        // Validate data sizes
        guard !meshData.verticesData.isEmpty,
              !meshData.facesData.isEmpty else {
            return false
        }
        
        // Validate compression ratio
        guard meshData.compressionRatio > 0 && meshData.compressionRatio <= 1.0 else {
            return false
        }
        
        return true
    }
}