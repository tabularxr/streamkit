import XCTest
import ARKit
import simd
@testable import StreamKit

final class CompressionEngineTests: XCTestCase {
    
    var compressionEngine: CompressionEngine!
    
    override func setUp() {
        super.setUp()
        compressionEngine = CompressionEngine()
    }
    
    override func tearDown() {
        compressionEngine = nil
        super.tearDown()
    }
    
    // MARK: - Compression Tests
    
    func testMeshCompression() {
        let expectation = XCTestExpectation(description: "Mesh compression completed")
        
        let mockMeshData = createMockMeshData()
        
        compressionEngine.compressMesh(mockMeshData) { compressedMesh in
            XCTAssertEqual(compressedMesh.anchorID, mockMeshData.anchorID)
            XCTAssertGreaterThan(compressedMesh.compressedVertices.count, 0)
            XCTAssertGreaterThan(compressedMesh.compressedFaces.count, 0)
            XCTAssertGreaterThan(compressedMesh.originalSize, 0)
            XCTAssertGreaterThan(compressedMesh.compressedSize, 0)
            XCTAssertGreaterThan(compressedMesh.compressionRatio, 0)
            XCTAssertLessThanOrEqual(compressedMesh.compressionRatio, 1.0)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCompressionLevels() {
        let mockMeshData = createMockMeshData()
        let levels: [CompressionLevel] = [.low, .medium, .high]
        
        for level in levels {
            compressionEngine.compressionLevel = level
            
            let expectation = XCTestExpectation(description: "Compression level \(level) test")
            
            compressionEngine.compressMesh(mockMeshData) { compressedMesh in
                XCTAssertGreaterThan(compressedMesh.compressedSize, 0)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testCompressionStatistics() {
        let initialRatio = compressionEngine.averageCompressionRatio
        XCTAssertEqual(initialRatio, 0.0) // No compression done yet
        
        let mockMeshData = createMockMeshData()
        let expectation = XCTestExpectation(description: "Statistics updated")
        
        compressionEngine.compressMesh(mockMeshData) { _ in
            let newRatio = self.compressionEngine.averageCompressionRatio
            XCTAssertGreaterThan(newRatio, 0.0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testEmptyMeshHandling() {
        let emptyMeshData = MeshData(
            anchorID: "empty-mesh",
            vertices: [],
            faces: [],
            normals: [],
            timestamp: Date().timeIntervalSince1970
        )
        
        let expectation = XCTestExpectation(description: "Empty mesh handling")
        
        compressionEngine.compressMesh(emptyMeshData) { compressedMesh in
            // Should handle empty mesh gracefully
            XCTAssertEqual(compressedMesh.anchorID, "empty-mesh")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Helper Methods
    
    private func createMockMeshData() -> MeshData {
        // Create a simple cube mesh
        let vertices: [SIMD3<Float>] = [
            SIMD3<Float>(-1, -1, -1), SIMD3<Float>(1, -1, -1),
            SIMD3<Float>(1, 1, -1), SIMD3<Float>(-1, 1, -1),
            SIMD3<Float>(-1, -1, 1), SIMD3<Float>(1, -1, 1),
            SIMD3<Float>(1, 1, 1), SIMD3<Float>(-1, 1, 1)
        ]
        
        let faces: [UInt32] = [
            0, 1, 2, 0, 2, 3, // front
            4, 6, 5, 4, 7, 6, // back
            4, 5, 1, 4, 1, 0, // bottom
            3, 2, 6, 3, 6, 7, // top
            4, 0, 3, 4, 3, 7, // left
            1, 5, 6, 1, 6, 2  // right
        ]
        
        let normals: [SIMD3<Float>] = vertices.map { _ in
            SIMD3<Float>(0, 1, 0) // Simple upward normals
        }
        
        return MeshData(
            anchorID: UUID().uuidString,
            vertices: vertices,
            faces: faces,
            normals: normals,
            timestamp: Date().timeIntervalSince1970
        )
    }
}