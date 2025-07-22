import XCTest
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
    
    func testCompressionDecompression() throws {
        // Create test mesh
        let mesh = createTestMesh()
        
        // Compress
        let compressed = try compressionEngine.compressMesh(mesh, level: .medium)
        
        // Verify compression occurred
        XCTAssertGreaterThan(compressed.originalSize, 0)
        XCTAssertGreaterThan(compressed.compressedSize, 0)
        XCTAssertLessThan(compressed.compressedSize, compressed.originalSize)
        
        // Decompress
        let decompressed = try compressionEngine.decompressMesh(compressed)
        
        // Verify data integrity
        XCTAssertEqual(decompressed.vertices.count, mesh.vertices.count)
        XCTAssertEqual(decompressed.faces.count, mesh.faces.count)
        
        // Check vertex accuracy (allowing for floating point precision)
        for (original, decompressed) in zip(mesh.vertices, decompressed.vertices) {
            XCTAssertEqual(original.x, decompressed.x, accuracy: 0.0001)
            XCTAssertEqual(original.y, decompressed.y, accuracy: 0.0001)
            XCTAssertEqual(original.z, decompressed.z, accuracy: 0.0001)
        }
        
        // Check face accuracy
        XCTAssertEqual(mesh.faces, decompressed.faces)
    }
    
    func testCompressionLevels() throws {
        let mesh = createTestMesh(vertexCount: 1000)
        
        var compressionSizes: [CompressionLevel: Int] = [:]
        
        for level in CompressionLevel.allCases {
            let compressed = try compressionEngine.compressMesh(mesh, level: level)
            compressionSizes[level] = compressed.compressedSize
        }
        
        // Verify compression levels produce expected results
        if let noneSize = compressionSizes[.none],
           let lowSize = compressionSizes[.low],
           let mediumSize = compressionSizes[.medium],
           let highSize = compressionSizes[.high],
           let maxSize = compressionSizes[.maximum] {
            
            // Higher compression should produce smaller files
            XCTAssertGreaterThan(noneSize, lowSize)
            XCTAssertGreaterThan(lowSize, mediumSize)
            XCTAssertGreaterThanOrEqual(mediumSize, highSize)
            XCTAssertGreaterThanOrEqual(highSize, maxSize)
        }
    }
    
    func testCompressionWithNormals() throws {
        // Create mesh with normals
        let vertices = (0..<100).map { i in
            SIMD3<Float>(Float(i), Float(i) * 2, Float(i) * 3)
        }
        let normals = vertices.map { normalize($0) }
        let faces = (0..<99).flatMap { i in
            [UInt32(0), UInt32(i), UInt32(i + 1)]
        }
        
        let mesh = MeshData(
            vertices: vertices,
            faces: faces,
            normals: normals
        )
        
        // Compress and decompress
        let compressed = try compressionEngine.compressMesh(mesh, level: .medium)
        XCTAssertNotNil(compressed.normals)
        
        let decompressed = try compressionEngine.decompressMesh(compressed)
        
        // Verify normals preserved
        XCTAssertEqual(decompressed.normals.count, mesh.normals.count)
        
        for (original, decompressed) in zip(mesh.normals, decompressed.normals) {
            XCTAssertEqual(original.x, decompressed.x, accuracy: 0.0001)
            XCTAssertEqual(original.y, decompressed.y, accuracy: 0.0001)
            XCTAssertEqual(original.z, decompressed.z, accuracy: 0.0001)
        }
    }
    
    func testCompressionStatistics() throws {
        compressionEngine.resetStatistics()
        
        XCTAssertEqual(compressionEngine.totalOriginalBytes, 0)
        XCTAssertEqual(compressionEngine.totalCompressedBytes, 0)
        XCTAssertEqual(compressionEngine.compressionCount, 0)
        
        // Compress multiple meshes
        for i in 0..<5 {
            let mesh = createTestMesh(vertexCount: 100 * (i + 1))
            _ = try compressionEngine.compressMesh(mesh, level: .medium)
        }
        
        XCTAssertEqual(compressionEngine.compressionCount, 5)
        XCTAssertGreaterThan(compressionEngine.totalOriginalBytes, 0)
        XCTAssertGreaterThan(compressionEngine.totalCompressedBytes, 0)
        XCTAssertGreaterThan(compressionEngine.compressionRatio, 0)
        XCTAssertLessThan(compressionEngine.compressionRatio, 1)
    }
    
    func testEmptyMeshCompression() throws {
        let emptyMesh = MeshData(vertices: [], faces: [])
        
        let compressed = try compressionEngine.compressMesh(emptyMesh, level: .medium)
        let decompressed = try compressionEngine.decompressMesh(compressed)
        
        XCTAssertEqual(decompressed.vertices.count, 0)
        XCTAssertEqual(decompressed.faces.count, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestMesh(vertexCount: Int = 100) -> MeshData {
        var vertices: [SIMD3<Float>] = []
        var faces: [UInt32] = []
        
        // Create a simple sphere-like mesh
        for i in 0..<vertexCount {
            let theta = Float(i) * 2 * .pi / Float(vertexCount)
            let phi = Float(i) * .pi / Float(vertexCount)
            
            let x = sin(phi) * cos(theta)
            let y = sin(phi) * sin(theta)
            let z = cos(phi)
            
            vertices.append(SIMD3<Float>(x, y, z))
        }
        
        // Create triangle faces
        for i in 0..<vertexCount-2 {
            faces.append(contentsOf: [0, UInt32(i + 1), UInt32(i + 2)])
        }
        
        return MeshData(vertices: vertices, faces: faces)
    }
}

// MARK: - Performance Tests

extension CompressionEngineTests {
    
    func testCompressionPerformance() throws {
        let largeMesh = createTestMesh(vertexCount: 10000)
        
        measure {
            _ = try? compressionEngine.compressMesh(largeMesh, level: .medium)
        }
    }
    
    func testDecompressionPerformance() throws {
        let largeMesh = createTestMesh(vertexCount: 10000)
        let compressed = try compressionEngine.compressMesh(largeMesh, level: .medium)
        
        measure {
            _ = try? compressionEngine.decompressMesh(compressed)
        }
    }
}