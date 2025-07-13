import XCTest
import simd
@testable import StreamKit

final class DataModelsTests: XCTestCase {
    
    // MARK: - PoseData Tests
    
    func testPoseDataInitialization() {
        let transform = simd_float4x4(
            simd_float4(1, 0, 0, 2),  // x = 2
            simd_float4(0, 1, 0, 3),  // y = 3
            simd_float4(0, 0, 1, 4),  // z = 4
            simd_float4(0, 0, 0, 1)
        )
        
        let timestamp = Date().timeIntervalSince1970
        let poseData = PoseData(transform: transform, timestamp: timestamp)
        
        XCTAssertEqual(poseData.position.x, 2.0, accuracy: 0.001)
        XCTAssertEqual(poseData.position.y, 3.0, accuracy: 0.001)
        XCTAssertEqual(poseData.position.z, 4.0, accuracy: 0.001)
        XCTAssertEqual(poseData.timestamp, timestamp, accuracy: 0.001)
        
        // Quaternion should be normalized
        let quatMagnitude = sqrt(
            poseData.rotation.vector.x * poseData.rotation.vector.x +
            poseData.rotation.vector.y * poseData.rotation.vector.y +
            poseData.rotation.vector.z * poseData.rotation.vector.z +
            poseData.rotation.vector.w * poseData.rotation.vector.w
        )
        XCTAssertEqual(quatMagnitude, 1.0, accuracy: 0.001)
    }
    
    // MARK: - MeshData Tests
    
    func testMeshDataBasicProperties() {
        let meshData = createMockMeshData()
        
        XCTAssertFalse(meshData.anchorID.isEmpty)
        XCTAssertGreaterThan(meshData.vertices.count, 0)
        XCTAssertGreaterThan(meshData.faces.count, 0)
        XCTAssertGreaterThan(meshData.timestamp, 0)
    }
    
    // MARK: - CompressedMeshData Tests
    
    func testCompressedMeshDataCompressionRatio() {
        let compressedMesh = CompressedMeshData(
            anchorID: "test-anchor",
            compressedVertices: Data([1, 2, 3]),
            compressedFaces: Data([4, 5]),
            compressedNormals: nil,
            originalSize: 100,
            compressedSize: 50,
            timestamp: Date().timeIntervalSince1970
        )
        
        XCTAssertEqual(compressedMesh.compressionRatio, 0.5, accuracy: 0.001)
    }
    
    func testCompressedMeshDataZeroOriginalSize() {
        let compressedMesh = CompressedMeshData(
            anchorID: "test-anchor",
            compressedVertices: Data(),
            compressedFaces: Data(),
            compressedNormals: nil,
            originalSize: 0,
            compressedSize: 0,
            timestamp: Date().timeIntervalSince1970
        )
        
        XCTAssertEqual(compressedMesh.compressionRatio, 0.0, accuracy: 0.001)
    }
    
    // MARK: - SpatialPacket Tests
    
    func testSpatialPacketInitialization() {
        let poseData = PosePacketData(position: [1, 2, 3], rotation: [0, 0, 0, 1])
        let packet = SpatialPacket(
            sessionID: "test-session",
            frameNumber: 42,
            type: .pose,
            data: .pose(poseData)
        )
        
        XCTAssertEqual(packet.sessionID, "test-session")
        XCTAssertEqual(packet.frameNumber, 42)
        XCTAssertEqual(packet.type, .pose)
        XCTAssertFalse(packet.eventID.isEmpty)
        XCTAssertGreaterThan(packet.timestamp, 0)
    }
    
    func testPacketDataCoding() throws {
        // Test pose packet data
        let poseData = PosePacketData(position: [1, 2, 3], rotation: [0, 0, 0, 1])
        let posePacketData = PacketData.pose(poseData)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let encodedData = try encoder.encode(posePacketData)
        let decodedData = try decoder.decode(PacketData.self, from: encodedData)
        
        if case .pose(let decodedPose) = decodedData {
            XCTAssertEqual(decodedPose.position, [1, 2, 3])
            XCTAssertEqual(decodedPose.rotation, [0, 0, 0, 1])
        } else {
            XCTFail("Expected pose packet data")
        }
    }
    
    func testMeshPacketDataCoding() throws {
        let meshData = MeshPacketData(
            anchorID: "test-anchor",
            verticesData: Data([1, 2, 3]),
            facesData: Data([4, 5, 6]),
            normalsData: Data([7, 8, 9]),
            compressionRatio: 0.6
        )
        let meshPacketData = PacketData.mesh(meshData)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let encodedData = try encoder.encode(meshPacketData)
        let decodedData = try decoder.decode(PacketData.self, from: encodedData)
        
        if case .mesh(let decodedMesh) = decodedData {
            XCTAssertEqual(decodedMesh.anchorID, "test-anchor")
            XCTAssertEqual(decodedMesh.verticesData, Data([1, 2, 3]))
            XCTAssertEqual(decodedMesh.facesData, Data([4, 5, 6]))
            XCTAssertEqual(decodedMesh.normalsData, Data([7, 8, 9]))
            XCTAssertEqual(decodedMesh.compressionRatio, 0.6, accuracy: 0.001)
        } else {
            XCTFail("Expected mesh packet data")
        }
    }
    
    // MARK: - PosePacketData Tests
    
    func testPosePacketDataFromPoseData() {
        let transform = simd_float4x4(
            simd_float4(1, 0, 0, 5),
            simd_float4(0, 1, 0, 6),
            simd_float4(0, 0, 1, 7),
            simd_float4(0, 0, 0, 1)
        )
        
        let poseData = PoseData(transform: transform, timestamp: Date().timeIntervalSince1970)
        let posePacketData = PosePacketData(pose: poseData)
        
        XCTAssertEqual(posePacketData.position[0], 5.0, accuracy: 0.001)
        XCTAssertEqual(posePacketData.position[1], 6.0, accuracy: 0.001)
        XCTAssertEqual(posePacketData.position[2], 7.0, accuracy: 0.001)
        XCTAssertEqual(posePacketData.rotation.count, 4)
    }
    
    // MARK: - MeshPacketData Tests
    
    func testMeshPacketDataFromCompressedMesh() {
        let compressedMesh = CompressedMeshData(
            anchorID: "test-anchor-123",
            compressedVertices: Data([1, 2, 3, 4]),
            compressedFaces: Data([5, 6, 7]),
            compressedNormals: Data([8, 9]),
            originalSize: 200,
            compressedSize: 100,
            timestamp: Date().timeIntervalSince1970
        )
        
        let meshPacketData = MeshPacketData(compressedMesh: compressedMesh)
        
        XCTAssertEqual(meshPacketData.anchorID, "test-anchor-123")
        XCTAssertEqual(meshPacketData.verticesData, Data([1, 2, 3, 4]))
        XCTAssertEqual(meshPacketData.facesData, Data([5, 6, 7]))
        XCTAssertEqual(meshPacketData.normalsData, Data([8, 9]))
        XCTAssertEqual(meshPacketData.compressionRatio, 0.5, accuracy: 0.001)
    }
    
    // MARK: - SessionMetrics Tests
    
    func testSessionMetricsInitialization() {
        let metrics = SessionMetrics(
            sessionID: "test-session",
            framesSent: 100,
            meshesSent: 20,
            compressionRatio: 0.7,
            connectionUptime: 30.5
        )
        
        XCTAssertEqual(metrics.sessionID, "test-session")
        XCTAssertEqual(metrics.framesSent, 100)
        XCTAssertEqual(metrics.meshesSent, 20)
        XCTAssertEqual(metrics.compressionRatio, 0.7, accuracy: 0.001)
        XCTAssertEqual(metrics.connectionUptime, 30.5, accuracy: 0.001)
    }
    
    // MARK: - CompressionLevel Tests
    
    func testCompressionLevelRawValues() {
        XCTAssertEqual(CompressionLevel.low.rawValue, 1)
        XCTAssertEqual(CompressionLevel.medium.rawValue, 5)
        XCTAssertEqual(CompressionLevel.high.rawValue, 9)
    }
    
    func testCompressionLevelDracoMapping() {
        XCTAssertEqual(CompressionLevel.low.dracoCompressionLevel, 1)
        XCTAssertEqual(CompressionLevel.medium.dracoCompressionLevel, 5)
        XCTAssertEqual(CompressionLevel.high.dracoCompressionLevel, 9)
    }
    
    // MARK: - Helper Methods
    
    private func createMockMeshData() -> MeshData {
        return MeshData(
            anchorID: UUID().uuidString,
            vertices: [
                SIMD3<Float>(0, 0, 0),
                SIMD3<Float>(1, 0, 0),
                SIMD3<Float>(0, 1, 0)
            ],
            faces: [0, 1, 2],
            normals: [
                SIMD3<Float>(0, 0, 1),
                SIMD3<Float>(0, 0, 1),
                SIMD3<Float>(0, 0, 1)
            ],
            timestamp: Date().timeIntervalSince1970
        )
    }
}