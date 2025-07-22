import Foundation
import simd

/// Efficient mesh diffing using spatial hashing
public class MeshDiffer {
    
    // Spatial grid size for hashing vertices (10cm cubes)
    private let gridSize: Float = 0.1
    
    // Tolerance for vertex comparison (1mm)
    private let vertexTolerance: Float = 0.001
    
    // Cache of previous meshes
    private var meshCache: [String: CachedMesh] = [:]
    
    // Maximum cache size (keep last 10 meshes)
    private let maxCacheSize = 10
    
    private struct CachedMesh {
        let vertices: [SIMD3<Float>]
        let faces: [UInt32]
        let spatialHash: [Int: Set<Int>] // Grid hash -> vertex indices
        let timestamp: Date
    }
    
    public init() {}
    
    /// Compute mesh difference between base and new mesh
    /// Returns delta mesh with only changed regions
    public func computeDiff(baseMeshId: String, newMesh: MeshData) -> MeshDelta {
        // Check if we have the base mesh cached
        guard let baseMesh = meshCache[baseMeshId] else {
            // No base mesh, return full mesh as delta
            cacheMesh(id: newMesh.id.uuidString, mesh: newMesh)
            return MeshDelta(
                id: newMesh.id.uuidString,
                baseMeshId: nil,
                addedVertices: Array(0..<newMesh.vertices.count),
                modifiedVertices: [],
                removedVertices: [],
                faces: newMesh.faces,
                compressionRatio: 1.0
            )
        }
        
        // Build spatial hash for new mesh
        let newSpatialHash = buildSpatialHash(vertices: newMesh.vertices)
        
        // Find changed vertices
        var addedVertices: [Int] = []
        var modifiedVertices: [(index: Int, oldIndex: Int)] = []
        var vertexMapping: [Int: Int] = [:] // new index -> base index
        
        // Check each vertex in new mesh
        for (newIndex, newVertex) in newMesh.vertices.enumerated() {
            let gridKey = spatialHashKey(for: newVertex)
            var foundMatch = false
            
            // Check nearby grid cells
            for offset in gridOffsets() {
                let checkKey = gridKey + offset
                if let baseIndices = baseMesh.spatialHash[checkKey] {
                    // Check vertices in this grid cell
                    for baseIndex in baseIndices {
                        if distance(newVertex, baseMesh.vertices[baseIndex]) < vertexTolerance {
                            // Found matching vertex
                            vertexMapping[newIndex] = baseIndex
                            
                            // Check if vertex moved slightly
                            if distance(newVertex, baseMesh.vertices[baseIndex]) > 0.0001 {
                                modifiedVertices.append((newIndex, baseIndex))
                            }
                            foundMatch = true
                            break
                        }
                    }
                }
                if foundMatch { break }
            }
            
            if !foundMatch {
                addedVertices.append(newIndex)
            }
        }
        
        // Find removed vertices (in base but not in new)
        var removedVertices: [Int] = []
        let mappedBaseIndices = Set(vertexMapping.values)
        for baseIndex in 0..<baseMesh.vertices.count {
            if !mappedBaseIndices.contains(baseIndex) {
                removedVertices.append(baseIndex)
            }
        }
        
        // Extract only faces that reference changed vertices
        let changedVertexSet = Set(addedVertices + modifiedVertices.map { $0.index })
        var deltaFaces: [UInt32] = []
        
        for i in stride(from: 0, to: newMesh.faces.count, by: 3) {
            let v0 = Int(newMesh.faces[i])
            let v1 = Int(newMesh.faces[i + 1])
            let v2 = Int(newMesh.faces[i + 2])
            
            // Include face if any vertex is changed
            if changedVertexSet.contains(v0) || 
               changedVertexSet.contains(v1) || 
               changedVertexSet.contains(v2) {
                deltaFaces.append(contentsOf: [newMesh.faces[i], newMesh.faces[i + 1], newMesh.faces[i + 2]])
            }
        }
        
        // Calculate compression ratio
        let originalSize = newMesh.vertices.count * 12 + newMesh.faces.count * 4 // Approximate byte size
        let deltaSize = (addedVertices.count + modifiedVertices.count) * 12 + deltaFaces.count * 4
        let compressionRatio = Double(deltaSize) / Double(originalSize)
        
        // Cache the new mesh
        cacheMesh(id: newMesh.id.uuidString, mesh: newMesh)
        
        // Clean up old cache entries
        cleanupCache()
        
        return MeshDelta(
            id: newMesh.id.uuidString,
            baseMeshId: baseMeshId,
            addedVertices: addedVertices,
            modifiedVertices: modifiedVertices,
            removedVertices: removedVertices,
            faces: deltaFaces,
            compressionRatio: compressionRatio
        )
    }
    
    /// Apply delta to reconstruct full mesh
    public func applyDelta(baseMeshId: String, delta: MeshDelta) -> MeshData? {
        guard let baseMesh = meshCache[baseMeshId] else {
            return nil
        }
        
        // Start with base vertices
        var reconstructedVertices = baseMesh.vertices
        
        // Apply modifications
        for (newIndex, oldIndex) in delta.modifiedVertices {
            if oldIndex < reconstructedVertices.count {
                // Note: In a real delta, we'd store the new position
                // For now, we're just tracking which vertices changed
            }
        }
        
        // Add new vertices
        // Note: In a real implementation, delta would include the actual vertex data
        
        // Remove vertices (shift indices)
        // Note: This is complex and requires remapping face indices
        
        return MeshData(
            id: UUID(uuidString: delta.id) ?? UUID(),
            vertices: reconstructedVertices,
            faces: Array(delta.faces),
            normals: [],
            timestamp: Date()
        )
    }
    
    // MARK: - Private Helpers
    
    private func buildSpatialHash(vertices: [SIMD3<Float>]) -> [Int: Set<Int>] {
        var hash: [Int: Set<Int>] = [:]
        
        for (index, vertex) in vertices.enumerated() {
            let key = spatialHashKey(for: vertex)
            hash[key, default: Set()].insert(index)
        }
        
        return hash
    }
    
    private func spatialHashKey(for vertex: SIMD3<Float>) -> Int {
        let x = Int(floor(vertex.x / gridSize))
        let y = Int(floor(vertex.y / gridSize))
        let z = Int(floor(vertex.z / gridSize))
        
        // Simple hash function (can be improved)
        return x &+ y &* 73856093 &+ z &* 19349663
    }
    
    private func gridOffsets() -> [Int] {
        // Check neighboring grid cells (3x3x3 cube)
        var offsets: [Int] = []
        for dx in -1...1 {
            for dy in -1...1 {
                for dz in -1...1 {
                    let offset = dx &+ dy &* 73856093 &+ dz &* 19349663
                    offsets.append(offset)
                }
            }
        }
        return offsets
    }
    
    private func distance(_ v1: SIMD3<Float>, _ v2: SIMD3<Float>) -> Float {
        return simd_distance(v1, v2)
    }
    
    private func cacheMesh(id: String, mesh: MeshData) {
        let spatialHash = buildSpatialHash(vertices: mesh.vertices)
        meshCache[id] = CachedMesh(
            vertices: mesh.vertices,
            faces: mesh.faces,
            spatialHash: spatialHash,
            timestamp: mesh.timestamp
        )
    }
    
    private func cleanupCache() {
        if meshCache.count > maxCacheSize {
            // Remove oldest entries
            let sortedEntries = meshCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sortedEntries.prefix(meshCache.count - maxCacheSize)
            for (key, _) in toRemove {
                meshCache.removeValue(forKey: key)
            }
        }
    }
}

// MARK: - Mesh Delta Structure

public struct MeshDelta: Codable {
    public let id: String
    public let baseMeshId: String?
    public let addedVertices: [Int]      // Indices of new vertices
    public let modifiedVertices: [(index: Int, oldIndex: Int)] // Modified vertex mappings
    public let removedVertices: [Int]    // Indices of removed vertices
    public let faces: [UInt32]           // Only faces referencing changed vertices
    public let compressionRatio: Double
    
    // Custom coding for tuple array
    private enum CodingKeys: String, CodingKey {
        case id, baseMeshId, addedVertices, removedVertices, faces, compressionRatio
        case modifiedVerticesIndices, modifiedVerticesOldIndices
    }
    
    public init(id: String, baseMeshId: String?, addedVertices: [Int], 
                modifiedVertices: [(index: Int, oldIndex: Int)], 
                removedVertices: [Int], faces: [UInt32], compressionRatio: Double) {
        self.id = id
        self.baseMeshId = baseMeshId
        self.addedVertices = addedVertices
        self.modifiedVertices = modifiedVertices
        self.removedVertices = removedVertices
        self.faces = faces
        self.compressionRatio = compressionRatio
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        baseMeshId = try container.decodeIfPresent(String.self, forKey: .baseMeshId)
        addedVertices = try container.decode([Int].self, forKey: .addedVertices)
        removedVertices = try container.decode([Int].self, forKey: .removedVertices)
        faces = try container.decode([UInt32].self, forKey: .faces)
        compressionRatio = try container.decode(Double.self, forKey: .compressionRatio)
        
        let indices = try container.decode([Int].self, forKey: .modifiedVerticesIndices)
        let oldIndices = try container.decode([Int].self, forKey: .modifiedVerticesOldIndices)
        modifiedVertices = Array(zip(indices, oldIndices))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(baseMeshId, forKey: .baseMeshId)
        try container.encode(addedVertices, forKey: .addedVertices)
        try container.encode(removedVertices, forKey: .removedVertices)
        try container.encode(faces, forKey: .faces)
        try container.encode(compressionRatio, forKey: .compressionRatio)
        
        try container.encode(modifiedVertices.map { $0.index }, forKey: .modifiedVerticesIndices)
        try container.encode(modifiedVertices.map { $0.oldIndex }, forKey: .modifiedVerticesOldIndices)
    }
}