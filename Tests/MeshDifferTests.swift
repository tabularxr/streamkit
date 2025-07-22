import XCTest
import simd
@testable import StreamKit

final class MeshDifferTests: XCTestCase {
    
    var meshDiffer: MeshDiffer!
    
    override func setUp() {
        super.setUp()
        meshDiffer = MeshDiffer()
    }
    
    override func tearDown() {
        meshDiffer = nil
        super.tearDown()
    }
    
    func testIdenticalMeshProducesMinimalDelta() {
        // Create a test mesh
        let mesh = createTestMesh(vertexCount: 100)
        
        // Compute diff with itself
        let delta = meshDiffer.computeDiff(baseMeshId: mesh.id.uuidString, newMesh: mesh)
        
        // Should have no added or removed vertices
        XCTAssertEqual(delta.addedVertices.count, 0)
        XCTAssertEqual(delta.removedVertices.count, 0)
        XCTAssertEqual(delta.modifiedVertices.count, 0)
        
        // Compression ratio should be very low (minimal data)
        XCTAssertLessThan(delta.compressionRatio, 0.1)
    }
    
    func testCompletelyDifferentMeshProducesFullDelta() {
        // Create two different meshes
        let mesh1 = createTestMesh(vertexCount: 100, offset: 0)
        let mesh2 = createTestMesh(vertexCount: 100, offset: 10)
        
        // First mesh has no base
        let delta1 = meshDiffer.computeDiff(baseMeshId: "non-existent", newMesh: mesh1)
        XCTAssertNil(delta1.baseMeshId)
        XCTAssertEqual(delta1.addedVertices.count, 100)
        
        // Second mesh compared to first
        let delta2 = meshDiffer.computeDiff(baseMeshId: mesh1.id.uuidString, newMesh: mesh2)
        XCTAssertEqual(delta2.baseMeshId, mesh1.id.uuidString)
        
        // Should detect all vertices as new (too far apart)
        XCTAssertEqual(delta2.addedVertices.count, 100)
        XCTAssertEqual(delta2.removedVertices.count, 100)
    }
    
    func testPartialMeshUpdate() {
        // Create base mesh
        var vertices1: [SIMD3<Float>] = []
        for i in 0..<100 {
            let angle = Float(i) * .pi * 2 / 100
            vertices1.append(SIMD3<Float>(cos(angle), 0, sin(angle)))
        }
        let mesh1 = MeshData(vertices: vertices1, faces: createTestFaces(vertexCount: 100))
        
        // Create modified mesh (move half the vertices slightly)
        var vertices2 = vertices1
        for i in 0..<50 {
            vertices2[i].y += 0.0005 // Move slightly within tolerance
        }
        for i in 50..<60 {
            vertices2[i].y += 0.1 // Move significantly
        }
        let mesh2 = MeshData(vertices: vertices2, faces: createTestFaces(vertexCount: 100))
        
        // Compute diff
        let _ = meshDiffer.computeDiff(baseMeshId: mesh1.id.uuidString, newMesh: mesh1)
        let delta = meshDiffer.computeDiff(baseMeshId: mesh1.id.uuidString, newMesh: mesh2)
        
        // Should detect the 10 significantly moved vertices
        XCTAssertGreaterThan(delta.modifiedVertices.count, 5)
        XCTAssertLessThan(delta.modifiedVertices.count, 15)
        
        // Should include faces that reference modified vertices
        XCTAssertGreaterThan(delta.faces.count, 0)
        XCTAssertLessThan(delta.compressionRatio, 0.5)
    }
    
    func testMeshCacheCleanup() {
        // Create more meshes than cache size (10)
        for i in 0..<15 {
            let mesh = createTestMesh(vertexCount: 10, offset: Float(i))
            _ = meshDiffer.computeDiff(baseMeshId: "base-\(i)", newMesh: mesh)
        }
        
        // Early meshes should be evicted, recent ones should work
        let testMesh = createTestMesh(vertexCount: 10)
        
        // This should fail (evicted)
        let deltaOld = meshDiffer.computeDiff(baseMeshId: "base-0", newMesh: testMesh)
        XCTAssertNil(deltaOld.baseMeshId)
        
        // This should work (still in cache)
        let deltaRecent = meshDiffer.computeDiff(baseMeshId: testMesh.id.uuidString, newMesh: testMesh)
        XCTAssertNotNil(deltaRecent.baseMeshId)
    }
    
    // MARK: - Helper Methods
    
    private func createTestMesh(vertexCount: Int, offset: Float = 0) -> MeshData {
        var vertices: [SIMD3<Float>] = []
        
        for i in 0..<vertexCount {
            let angle = Float(i) * .pi * 2 / Float(vertexCount)
            let x = cos(angle) + offset
            let y = Float(i) * 0.01
            let z = sin(angle) + offset
            vertices.append(SIMD3<Float>(x, y, z))
        }
        
        let faces = createTestFaces(vertexCount: vertexCount)
        
        return MeshData(
            vertices: vertices,
            faces: faces,
            normals: []
        )
    }
    
    private func createTestFaces(vertexCount: Int) -> [UInt32] {
        var faces: [UInt32] = []
        
        // Create triangle fan
        for i in 1..<vertexCount-1 {
            faces.append(0)
            faces.append(UInt32(i))
            faces.append(UInt32(i + 1))
        }
        
        return faces
    }
}

// MARK: - Performance Tests

extension MeshDifferTests {
    
    func testPerformanceLargeMesh() {
        let largeMesh = createTestMesh(vertexCount: 10000)
        
        measure {
            _ = meshDiffer.computeDiff(baseMeshId: "base", newMesh: largeMesh)
        }
    }
    
    func testPerformanceMultipleDiffs() {
        let meshes = (0..<10).map { createTestMesh(vertexCount: 1000, offset: Float($0) * 0.1) }
        
        measure {
            for i in 1..<meshes.count {
                _ = meshDiffer.computeDiff(baseMeshId: meshes[i-1].id.uuidString, newMesh: meshes[i])
            }
        }
    }
}