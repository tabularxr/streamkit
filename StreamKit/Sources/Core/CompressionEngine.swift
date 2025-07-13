import Foundation
import Compression

class CompressionEngine {
    
    // MARK: - Properties
    
    var compressionLevel: CompressionLevel = .medium
    
    private var totalOriginalSize: Int = 0
    private var totalCompressedSize: Int = 0
    private let compressionQueue = DispatchQueue(label: "com.streamkit.compression", qos: .userInitiated)
    
    var averageCompressionRatio: Double {
        guard totalOriginalSize > 0 else { return 0.0 }
        return Double(totalCompressedSize) / Double(totalOriginalSize)
    }
    
    // MARK: - Compression Methods
    
    func compressMesh(_ meshData: MeshData, completion: @escaping (CompressedMeshData) -> Void) {
        compressionQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let compressedMesh = try self.performCompression(meshData)
                
                // Update statistics
                self.totalOriginalSize += compressedMesh.originalSize
                self.totalCompressedSize += compressedMesh.compressedSize
                
                DispatchQueue.main.async {
                    completion(compressedMesh)
                }
            } catch {
                // Fallback to uncompressed data on error
                let fallbackMesh = self.createUncompressedMesh(meshData)
                
                DispatchQueue.main.async {
                    completion(fallbackMesh)
                }
            }
        }
    }
    
    // MARK: - Private Compression Implementation
    
    private func performCompression(_ meshData: MeshData) throws -> CompressedMeshData {
        // Compress vertices
        let verticesData = try encodeFloatArray(meshData.vertices.flatMap { [$0.x, $0.y, $0.z] })
        let compressedVertices = try compressData(verticesData)
        
        // Compress faces
        let facesData = Data(bytes: meshData.faces, count: meshData.faces.count * MemoryLayout<UInt32>.size)
        let compressedFaces = try compressData(facesData)
        
        // Compress normals if available
        var compressedNormals: Data?
        if !meshData.normals.isEmpty {
            let normalsData = try encodeFloatArray(meshData.normals.flatMap { [$0.x, $0.y, $0.z] })
            compressedNormals = try compressData(normalsData)
        }
        
        let originalSize = verticesData.count + facesData.count + (compressedNormals?.count ?? 0)
        let compressedSize = compressedVertices.count + compressedFaces.count + (compressedNormals?.count ?? 0)
        
        return CompressedMeshData(
            anchorID: meshData.anchorID,
            compressedVertices: compressedVertices,
            compressedFaces: compressedFaces,
            compressedNormals: compressedNormals,
            originalSize: originalSize,
            compressedSize: compressedSize,
            timestamp: meshData.timestamp
        )
    }
    
    private func compressData(_ data: Data) throws -> Data {
        let algorithm: Algorithm
        
        switch compressionLevel {
        case .low:
            algorithm = .lz4
        case .medium:
            algorithm = .lzfse
        case .high:
            algorithm = .lzma
        }
        
        guard let compressedData = try data.compressed(using: algorithm) else {
            throw StreamKitError.compressionError("Failed to compress data with \(algorithm)")
        }
        
        return compressedData
    }
    
    private func encodeFloatArray(_ floats: [Float]) throws -> Data {
        var data = Data()
        for float in floats {
            var value = float
            data.append(Data(bytes: &value, count: MemoryLayout<Float>.size))
        }
        return data
    }
    
    private func createUncompressedMesh(_ meshData: MeshData) -> CompressedMeshData {
        // Create uncompressed version as fallback
        let verticesData = try! encodeFloatArray(meshData.vertices.flatMap { [$0.x, $0.y, $0.z] })
        let facesData = Data(bytes: meshData.faces, count: meshData.faces.count * MemoryLayout<UInt32>.size)
        
        var normalsData: Data?
        if !meshData.normals.isEmpty {
            normalsData = try! encodeFloatArray(meshData.normals.flatMap { [$0.x, $0.y, $0.z] })
        }
        
        let totalSize = verticesData.count + facesData.count + (normalsData?.count ?? 0)
        
        return CompressedMeshData(
            anchorID: meshData.anchorID,
            compressedVertices: verticesData,
            compressedFaces: facesData,
            compressedNormals: normalsData,
            originalSize: totalSize,
            compressedSize: totalSize, // No compression achieved
            timestamp: meshData.timestamp
        )
    }
}

// MARK: - Data Compression Extension

private extension Data {
    func compressed(using algorithm: Algorithm) throws -> Data? {
        return try self.withUnsafeBytes { rawBytes in
            let buffer = rawBytes.bindMemory(to: UInt8.self)
            let compressedData = NSMutableData()
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
            defer { destinationBuffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                destinationBuffer, count,
                buffer.baseAddress!, count,
                nil, algorithm
            )
            
            guard compressedSize > 0 else {
                throw StreamKitError.compressionError("Compression failed")
            }
            
            return Data(bytes: destinationBuffer, count: compressedSize)
        }
    }
}