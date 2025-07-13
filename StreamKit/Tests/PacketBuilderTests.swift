import XCTest
import simd
@testable import StreamKit

final class PacketBuilderTests: XCTestCase {
    
    var packetBuilder: PacketBuilder!
    
    override func setUp() {
        super.setUp()
        packetBuilder = PacketBuilder()
    }
    
    override func tearDown() {
        packetBuilder = nil
        super.tearDown()
    }
    
    // MARK: - Pose Packet Tests
    
    func testBuildPosePacket() {
        let sessionID = "test-session"
        let frameNumber = 42
        let pose = createMockPose()
        
        let packet = packetBuilder.buildPosePacket(
            sessionID: sessionID,
            frameNumber: frameNumber,
            pose: pose
        )
        
        XCTAssertEqual(packet.sessionID, sessionID)
        XCTAssertEqual(packet.frameNumber, frameNumber)
        XCTAssertEqual(packet.type, .pose)
        XCTAssertFalse(packet.eventID.isEmpty)
        XCTAssertGreaterThan(packet.timestamp, 0)
        
        if case .pose(let poseData) = packet.data {
            XCTAssertEqual(poseData.position.count, 3)
            XCTAssertEqual(poseData.rotation.count, 4)
        } else {
            XCTFail("Expected pose packet data")
        }
    }
    
    func testBuildMeshPacket() {
        let sessionID = "test-session"
        let frameNumber = 43
        let compressedMesh = createMockCompressedMesh()
        
        let packet = packetBuilder.buildMeshPacket(
            sessionID: sessionID,
            frameNumber: frameNumber,
            mesh: compressedMesh
        )
        
        XCTAssertEqual(packet.sessionID, sessionID)
        XCTAssertEqual(packet.frameNumber, frameNumber)
        XCTAssertEqual(packet.type, .mesh)
        XCTAssertFalse(packet.eventID.isEmpty)
        XCTAssertGreaterThan(packet.timestamp, 0)
        
        if case .mesh(let meshData) = packet.data {
            XCTAssertEqual(meshData.anchorID, compressedMesh.anchorID)
            XCTAssertGreaterThan(meshData.verticesData.count, 0)
            XCTAssertGreaterThan(meshData.facesData.count, 0)
            XCTAssertGreaterThan(meshData.compressionRatio, 0)
        } else {
            XCTFail("Expected mesh packet data")
        }
    }
    
    // MARK: - Serialization Tests
    
    func testPacketSerialization() throws {
        let packet = packetBuilder.buildPosePacket(
            sessionID: "test-session",
            frameNumber: 1,
            pose: createMockPose()
        )
        
        let serializedData = try packetBuilder.serializePacket(packet)
        XCTAssertGreaterThan(serializedData.count, 0)
        
        // Test that it's valid JSON
        let jsonObject = try JSONSerialization.jsonObject(with: serializedData)
        XCTAssertNotNil(jsonObject)
    }
    
    func testPacketDeserialization() throws {
        let originalPacket = packetBuilder.buildPosePacket(
            sessionID: "test-session",
            frameNumber: 1,
            pose: createMockPose()
        )
        
        let serializedData = try packetBuilder.serializePacket(originalPacket)
        let deserializedPacket = try JSONDecoder().decode(SpatialPacket.self, from: serializedData)
        
        XCTAssertEqual(deserializedPacket.sessionID, originalPacket.sessionID)
        XCTAssertEqual(deserializedPacket.frameNumber, originalPacket.frameNumber)
        XCTAssertEqual(deserializedPacket.type, originalPacket.type)
        XCTAssertEqual(deserializedPacket.eventID, originalPacket.eventID)
    }
    
    // MARK: - Validation Tests
    
    func testValidPosePacketValidation() {
        let packet = packetBuilder.buildPosePacket(
            sessionID: "test-session",
            frameNumber: 1,
            pose: createMockPose()
        )
        
        XCTAssertTrue(packetBuilder.validatePacket(packet))
    }
    
    func testValidMeshPacketValidation() {
        let packet = packetBuilder.buildMeshPacket(
            sessionID: "test-session",
            frameNumber: 1,
            mesh: createMockCompressedMesh()
        )
        
        XCTAssertTrue(packetBuilder.validatePacket(packet))
    }
    
    func testInvalidPacketValidation() {
        // Test with empty session ID
        var invalidPacket = packetBuilder.buildPosePacket(
            sessionID: "",
            frameNumber: 1,
            pose: createMockPose()
        )
        
        XCTAssertFalse(packetBuilder.validatePacket(invalidPacket))
        
        // Test with negative frame number
        invalidPacket = packetBuilder.buildPosePacket(
            sessionID: "test-session",
            frameNumber: -1,
            pose: createMockPose()
        )
        
        XCTAssertFalse(packetBuilder.validatePacket(invalidPacket))
    }
    
    func testInvalidPoseDataValidation() {
        let invalidPose = PoseData(
            position: SIMD3<Float>(Float.infinity, 0, 0), // Invalid position
            rotation: simd_quatf(ix: 1, iy: 0, iz: 0, r: 0),
            timestamp: Date().timeIntervalSince1970
        )
        
        let packet = packetBuilder.buildPosePacket(
            sessionID: "test-session",
            frameNumber: 1,
            pose: invalidPose
        )
        
        XCTAssertFalse(packetBuilder.validatePacket(packet))
    }
    
    // MARK: - Helper Methods
    
    private func createMockPose() -> PoseData {
        let transform = simd_float4x4(
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(0, 0, 0, 1)
        )
        
        return PoseData(
            transform: transform,
            timestamp: Date().timeIntervalSince1970
        )
    }
    
    private func createMockCompressedMesh() -> CompressedMeshData {
        let mockVertices = Data([1, 2, 3, 4, 5])
        let mockFaces = Data([1, 2, 3])
        let mockNormals = Data([1, 2, 3, 4])
        
        return CompressedMeshData(
            anchorID: "test-anchor",
            compressedVertices: mockVertices,
            compressedFaces: mockFaces,
            compressedNormals: mockNormals,
            originalSize: 100,
            compressedSize: 50,
            timestamp: Date().timeIntervalSince1970
        )
    }
}