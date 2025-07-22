import Foundation
import Compression

/// Handles mesh data compression with consistent gzip format
public class CompressionEngine {
    
    // Standard gzip header
    private let gzipHeader: [UInt8] = [0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff]
    
    // Compression statistics
    public private(set) var totalOriginalBytes: Int64 = 0
    public private(set) var totalCompressedBytes: Int64 = 0
    public private(set) var compressionCount: Int = 0
    
    public init() {}
    
    /// Compress mesh data using gzip format
    public func compressMesh(_ meshData: MeshData, level: CompressionLevel = .medium) throws -> CompressedMeshData {
        let startTime = Date()
        
        // Serialize vertices and faces into a single buffer
        let vertexData = meshData.vertices.flatMap { vertex in
            [vertex.x, vertex.y, vertex.z]
        }
        let vertexBytes = vertexData.withUnsafeBytes { Data($0) }
        
        let faceBytes = meshData.faces.withUnsafeBytes { Data($0) }
        
        // Combine into a single buffer with header
        var combinedData = Data()
        
        // Add a simple header: vertex count (4 bytes) + face count (4 bytes)
        withUnsafeBytes(of: UInt32(meshData.vertices.count).littleEndian) { bytes in
            combinedData.append(contentsOf: bytes)
        }
        withUnsafeBytes(of: UInt32(meshData.faces.count).littleEndian) { bytes in
            combinedData.append(contentsOf: bytes)
        }
        
        // Append vertex and face data
        combinedData.append(vertexBytes)
        combinedData.append(faceBytes)
        
        // Compress with proper gzip format
        let compressedData = try compress(data: combinedData, level: level)
        
        // Handle normals if present
        var compressedNormals: Data?
        if !meshData.normals.isEmpty {
            let normalData = meshData.normals.flatMap { normal in
                [normal.x, normal.y, normal.z]
            }
            let normalBytes = normalData.withUnsafeBytes { Data($0) }
            compressedNormals = try compress(data: normalBytes, level: level)
        }
        
        // Update statistics
        let originalSize = combinedData.count + (compressedNormals?.count ?? 0)
        let compressedSize = compressedData.count + (compressedNormals?.count ?? 0)
        
        totalOriginalBytes += Int64(originalSize)
        totalCompressedBytes += Int64(compressedSize)
        compressionCount += 1
        
        let compressionTime = Date().timeIntervalSince(startTime)
        
        return CompressedMeshData(
            id: meshData.id.uuidString,
            anchorId: "", // Will be set by caller
            vertices: compressedData,
            faces: Data(), // Combined in vertices data
            normals: compressedNormals,
            compressionLevel: level.rawValue,
            timestamp: meshData.timestamp,
            originalSize: originalSize,
            compressedSize: compressedSize
        )
    }
    
    /// Decompress mesh data
    public func decompressMesh(_ compressedData: CompressedMeshData) throws -> MeshData {
        // Decompress the combined data
        let decompressedData = try decompress(data: compressedData.vertices)
        
        // Read header
        guard decompressedData.count >= 8 else {
            throw CompressionError.invalidData("Data too small for header")
        }
        
        let vertexCount = decompressedData.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: 0, as: UInt32.self).littleEndian
        }
        let faceCount = decompressedData.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: 4, as: UInt32.self).littleEndian
        }
        
        // Calculate expected data size
        let vertexDataSize = Int(vertexCount) * 3 * MemoryLayout<Float>.size
        let faceDataSize = Int(faceCount) * MemoryLayout<UInt32>.size
        let expectedSize = 8 + vertexDataSize + faceDataSize
        
        guard decompressedData.count >= expectedSize else {
            throw CompressionError.invalidData("Decompressed data size mismatch")
        }
        
        // Extract vertex data
        var vertices: [SIMD3<Float>] = []
        vertices.reserveCapacity(Int(vertexCount))
        
        let vertexStart = 8
        decompressedData.withUnsafeBytes { bytes in
            let floatPointer = bytes.baseAddress!.advanced(by: vertexStart).assumingMemoryBound(to: Float.self)
            for i in 0..<Int(vertexCount) {
                let x = floatPointer[i * 3]
                let y = floatPointer[i * 3 + 1]
                let z = floatPointer[i * 3 + 2]
                vertices.append(SIMD3<Float>(x, y, z))
            }
        }
        
        // Extract face data
        var faces: [UInt32] = []
        faces.reserveCapacity(Int(faceCount))
        
        let faceStart = vertexStart + vertexDataSize
        decompressedData.withUnsafeBytes { bytes in
            let uint32Pointer = bytes.baseAddress!.advanced(by: faceStart).assumingMemoryBound(to: UInt32.self)
            faces = Array(UnsafeBufferPointer(start: uint32Pointer, count: Int(faceCount)))
        }
        
        // Decompress normals if present
        var normals: [SIMD3<Float>] = []
        if let compressedNormals = compressedData.normals {
            let normalData = try decompress(data: compressedNormals)
            normalData.withUnsafeBytes { bytes in
                let floatPointer = bytes.baseAddress!.assumingMemoryBound(to: Float.self)
                for i in 0..<Int(vertexCount) {
                    let x = floatPointer[i * 3]
                    let y = floatPointer[i * 3 + 1]
                    let z = floatPointer[i * 3 + 2]
                    normals.append(SIMD3<Float>(x, y, z))
                }
            }
        }
        
        return MeshData(
            id: UUID(uuidString: compressedData.id) ?? UUID(),
            vertices: vertices,
            faces: faces,
            normals: normals,
            timestamp: compressedData.timestamp
        )
    }
    
    // MARK: - Private Compression Methods
    
    private func compress(data: Data, level: CompressionLevel) throws -> Data {
        return try data.compressed(using: .gzip, level: level.compressionAlgorithmLevel)
    }
    
    private func decompress(data: Data) throws -> Data {
        return try data.decompressed(using: .gzip)
    }
    
    /// Get compression statistics
    public var compressionRatio: Double {
        guard totalOriginalBytes > 0 else { return 0 }
        return Double(totalCompressedBytes) / Double(totalOriginalBytes)
    }
    
    /// Reset statistics
    public func resetStatistics() {
        totalOriginalBytes = 0
        totalCompressedBytes = 0
        compressionCount = 0
    }
}

// MARK: - Compression Level

public enum CompressionLevel: Int, CaseIterable {
    case none = 0
    case low = 3
    case medium = 5
    case high = 7
    case maximum = 9
    
    var compressionAlgorithmLevel: Int {
        switch self {
        case .none: return 0
        case .low: return 3
        case .medium: return 5
        case .high: return 7
        case .maximum: return 9
        }
    }
}

// MARK: - Errors

public enum CompressionError: LocalizedError {
    case compressionFailed(String)
    case decompressionFailed(String)
    case invalidData(String)
    
    public var errorDescription: String? {
        switch self {
        case .compressionFailed(let detail):
            return "Compression failed: \(detail)"
        case .decompressionFailed(let detail):
            return "Decompression failed: \(detail)"
        case .invalidData(let detail):
            return "Invalid data: \(detail)"
        }
    }
}

// MARK: - Data Extension for Compression

extension Data {
    func compressed(using algorithm: NSData.CompressionAlgorithm, level: Int) throws -> Data {
        guard let compressed = (self as NSData).compressed(using: algorithm) else {
            throw CompressionError.compressionFailed("Failed to compress data")
        }
        return compressed as Data
    }
    
    func decompressed(using algorithm: NSData.CompressionAlgorithm) throws -> Data {
        guard let decompressed = (self as NSData).decompressed(using: algorithm) else {
            throw CompressionError.decompressionFailed("Failed to decompress data")
        }
        return decompressed as Data
    }
}