import Foundation
import ARKit
import Combine

/// Main StreamKit SDK for visionOS spatial data streaming
public class StreamKit: NSObject {
    
    // MARK: - Properties
    
    // Core components
    private let streamingClient: StreamingClient
    private let compressionEngine: CompressionEngine
    private let meshDiffer: MeshDiffer
    
    // AR Session
    private var arSession: ARSession?
    private let arConfiguration = ARWorldTrackingConfiguration()
    
    // Session management
    public private(set) var sessionId: String?
    public private(set) var isStreaming = false
    public private(set) var sessionMetrics: SessionMetrics?
    
    // Frame processing
    private var lastPoseTime: Date = Date()
    private let poseInterval: TimeInterval = 1.0 / 30.0 // 30 FPS
    private var currentAnchorId: String?
    
    // Mesh buffering
    private var meshBuffer: [(mesh: MeshData, anchorId: String)] = []
    private var meshBufferTimer: Timer?
    private let meshBufferInterval: TimeInterval = 0.1 // 100ms
    private let maxMeshBufferSize = 10
    
    // Mesh tracking for diffing
    private var lastMeshIds: [UUID: String] = [:] // ARMeshAnchor.id -> our mesh ID
    
    // Delegate
    public weak var delegate: StreamKitDelegate?
    
    // Configuration
    public var compressionLevel: CompressionLevel = .medium
    public var enableMeshDiffing = true
    public var enableDebugLogging = false
    
    // MARK: - Initialization
    
    public init(serverURL: String, apiKey: String? = nil) {
        self.streamingClient = StreamingClient(serverURL: serverURL, apiKey: apiKey)
        self.compressionEngine = CompressionEngine()
        self.meshDiffer = MeshDiffer()
        
        super.init()
        
        self.streamingClient.delegate = self
        
        // Configure AR session
        configureARSession()
    }
    
    // MARK: - Public API
    
    /// Start streaming spatial data
    public func startStreaming() throws {
        guard !isStreaming else {
            throw StreamKitError.alreadyStreaming
        }
        
        guard ARWorldTrackingConfiguration.isSupported else {
            throw StreamKitError.arNotSupported
        }
        
        // Generate new session ID
        sessionId = UUID().uuidString
        currentAnchorId = UUID().uuidString
        
        // Initialize metrics
        sessionMetrics = SessionMetrics(sessionId: sessionId!)
        
        // Connect to server
        streamingClient.connect(sessionId: sessionId!)
        
        // Start AR session
        arSession?.run(arConfiguration)
        
        // Start mesh buffer timer
        startMeshBufferTimer()
        
        isStreaming = true
        
        log("Started streaming session: \(sessionId!)")
        delegate?.streamKitDidStartStreaming(self)
    }
    
    /// Stop streaming
    public func stopStreaming() {
        guard isStreaming else { return }
        
        // Flush any pending meshes
        flushMeshBuffer()
        
        // Stop timers
        stopMeshBufferTimer()
        
        // Stop AR session
        arSession?.pause()
        
        // Disconnect from server
        streamingClient.disconnect()
        
        // Update metrics
        if let metrics = sessionMetrics {
            sessionMetrics?.duration = Date().timeIntervalSince(metrics.startTime)
        }
        
        isStreaming = false
        
        log("Stopped streaming session: \(sessionId ?? "")")
        delegate?.streamKitDidStopStreaming(self)
    }
    
    /// Pause streaming temporarily
    public func pauseStreaming() {
        guard isStreaming else { return }
        
        arSession?.pause()
        stopMeshBufferTimer()
        
        log("Paused streaming")
        delegate?.streamKitDidPauseStreaming(self)
    }
    
    /// Resume streaming
    public func resumeStreaming() {
        guard isStreaming else { return }
        
        arSession?.run(arConfiguration)
        startMeshBufferTimer()
        
        log("Resumed streaming")
        delegate?.streamKitDidResumeStreaming(self)
    }
    
    // MARK: - AR Configuration
    
    private func configureARSession() {
        arSession = ARSession()
        arSession?.delegate = self
        
        // Configure for mesh capture
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            arConfiguration.sceneReconstruction = .mesh
        }
        
        // Enable auto focus
        if ARWorldTrackingConfiguration.supportsAutoFocus {
            arConfiguration.isAutoFocusEnabled = true
        }
        
        // Set world alignment
        arConfiguration.worldAlignment = .gravity
        
        // Enable light estimation
        arConfiguration.isLightEstimationEnabled = true
    }
    
    // MARK: - Mesh Buffering
    
    private func startMeshBufferTimer() {
        stopMeshBufferTimer()
        
        meshBufferTimer = Timer.scheduledTimer(withTimeInterval: meshBufferInterval, repeats: true) { [weak self] _ in
            self?.flushMeshBuffer()
        }
    }
    
    private func stopMeshBufferTimer() {
        meshBufferTimer?.invalidate()
        meshBufferTimer = nil
    }
    
    private func bufferMesh(_ mesh: MeshData, anchorId: String) {
        meshBuffer.append((mesh, anchorId))
        
        if meshBuffer.count >= maxMeshBufferSize {
            flushMeshBuffer()
        }
        
        sessionMetrics?.meshesProcessed += 1
    }
    
    private func flushMeshBuffer() {
        guard !meshBuffer.isEmpty else { return }
        
        let meshesToSend = meshBuffer
        meshBuffer.removeAll()
        
        Task {
            for (mesh, anchorId) in meshesToSend {
                await processMesh(mesh, anchorId: anchorId)
            }
        }
    }
    
    // MARK: - Mesh Processing
    
    private func processMesh(_ mesh: MeshData, anchorId: String) async {
        do {
            var meshUpdate: MeshUpdate
            
            if enableMeshDiffing, let lastMeshId = lastMeshIds[mesh.id] {
                // Compute delta from previous mesh
                let delta = meshDiffer.computeDiff(baseMeshId: lastMeshId, newMesh: mesh)
                
                if delta.compressionRatio < 0.8 { // Only use delta if it's significantly smaller
                    // Compress delta data
                    let deltaData = try encodeDelta(delta)
                    let compressedDelta = try compressionEngine.compress(data: deltaData, level: compressionLevel)
                    
                    meshUpdate = MeshUpdate(
                        id: mesh.id.uuidString,
                        anchorId: anchorId,
                        vertices: compressedDelta.base64EncodedString(),
                        faces: "", // Included in vertices for delta
                        normals: nil,
                        compressionLevel: compressionLevel.rawValue,
                        isDelta: true,
                        baseMeshId: lastMeshId
                    )
                    
                    log("Sending delta mesh: \(mesh.id.uuidString), compression ratio: \(String(format: "%.2f", delta.compressionRatio))")
                } else {
                    // Delta not worth it, send full mesh
                    meshUpdate = try await createFullMeshUpdate(mesh, anchorId: anchorId)
                }
            } else {
                // No previous mesh, send full
                meshUpdate = try await createFullMeshUpdate(mesh, anchorId: anchorId)
            }
            
            // Update last mesh ID
            lastMeshIds[mesh.id] = mesh.id.uuidString
            
            // Send update
            streamingClient.sendMeshUpdate(meshUpdate)
            
            // Update metrics
            let dataSize = meshUpdate.vertices.count + meshUpdate.faces.count
            sessionMetrics?.bytesTransmitted += Int64(dataSize)
            
        } catch {
            log("Failed to process mesh: \(error)")
            sessionMetrics?.errors += 1
            delegate?.streamKit(self, didEncounterError: error)
        }
    }
    
    private func createFullMeshUpdate(_ mesh: MeshData, anchorId: String) async throws -> MeshUpdate {
        // Compress mesh
        let compressed = try compressionEngine.compressMesh(mesh, level: compressionLevel)
        
        // Update compression metrics
        if let metrics = sessionMetrics {
            let currentRatio = compressionEngine.compressionRatio
            sessionMetrics?.compressionRatio = currentRatio
        }
        
        return MeshUpdate(
            id: mesh.id.uuidString,
            anchorId: anchorId,
            vertices: compressed.vertices.base64EncodedString(),
            faces: compressed.faces.base64EncodedString(),
            normals: compressed.normals?.base64EncodedString(),
            compressionLevel: compressionLevel.rawValue,
            isDelta: false,
            baseMeshId: nil
        )
    }
    
    private func encodeDelta(_ delta: MeshDelta) throws -> Data {
        return try JSONEncoder().encode(delta)
    }
    
    // MARK: - Logging
    
    private func log(_ message: String) {
        if enableDebugLogging {
            print("[StreamKit] \(message)")
        }
    }
}

// MARK: - ARSessionDelegate

extension StreamKit: ARSessionDelegate {
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isStreaming else { return }
        
        // Throttle pose updates to 30 FPS
        let now = Date()
        guard now.timeIntervalSince(lastPoseTime) >= poseInterval else { return }
        lastPoseTime = now
        
        // Extract pose from camera transform
        let pose = PoseData(from: frame.camera.transform)
        
        // Create anchor update
        let anchorUpdate = AnchorUpdate(
            id: currentAnchorId ?? UUID().uuidString,
            pose: pose,
            metadata: nil
        )
        
        // Send pose update
        streamingClient.sendAnchorUpdate(anchorUpdate)
        
        // Update metrics
        sessionMetrics?.framesProcessed += 1
    }
    
    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard isStreaming else { return }
        
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                handleMeshAnchor(meshAnchor)
            }
        }
    }
    
    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard isStreaming else { return }
        
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                handleMeshAnchor(meshAnchor)
            }
        }
    }
    
    private func handleMeshAnchor(_ meshAnchor: ARMeshAnchor) {
        guard let meshData = MeshData(from: meshAnchor) else {
            log("Failed to extract mesh data from anchor")
            return
        }
        
        // Buffer mesh for processing
        bufferMesh(meshData, anchorId: currentAnchorId ?? UUID().uuidString)
    }
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        log("AR session failed: \(error)")
        delegate?.streamKit(self, didEncounterError: error)
        
        // Attempt to recover
        if isStreaming {
            stopStreaming()
        }
    }
}

// MARK: - StreamingClientDelegate

extension StreamKit: StreamingClientDelegate {
    
    public func streamingClient(_ client: StreamingClient, didChangeState state: ConnectionState) {
        log("Connection state changed: \(state)")
        
        switch state {
        case .connected:
            delegate?.streamKitDidConnect(self)
        case .disconnected:
            delegate?.streamKitDidDisconnect(self)
        case .failed:
            if isStreaming {
                stopStreaming()
            }
        default:
            break
        }
    }
    
    public func streamingClient(_ client: StreamingClient, didReceiveMessage message: WSMessage) {
        // Handle incoming messages if needed
    }
    
    public func streamingClient(_ client: StreamingClient, didReceiveError error: String) {
        log("Received error from server: \(error)")
        delegate?.streamKit(self, didReceiveServerError: error)
    }
    
    public func streamingClient(_ client: StreamingClient, didFailWithError error: Error) {
        log("Streaming client error: \(error)")
        delegate?.streamKit(self, didEncounterError: error)
    }
}

// MARK: - Delegate Protocol

public protocol StreamKitDelegate: AnyObject {
    func streamKitDidStartStreaming(_ streamKit: StreamKit)
    func streamKitDidStopStreaming(_ streamKit: StreamKit)
    func streamKitDidPauseStreaming(_ streamKit: StreamKit)
    func streamKitDidResumeStreaming(_ streamKit: StreamKit)
    func streamKitDidConnect(_ streamKit: StreamKit)
    func streamKitDidDisconnect(_ streamKit: StreamKit)
    func streamKit(_ streamKit: StreamKit, didEncounterError error: Error)
    func streamKit(_ streamKit: StreamKit, didReceiveServerError error: String)
}

// MARK: - Errors

public enum StreamKitError: LocalizedError {
    case alreadyStreaming
    case notStreaming
    case arNotSupported
    case connectionFailed
    
    public var errorDescription: String? {
        switch self {
        case .alreadyStreaming:
            return "Already streaming"
        case .notStreaming:
            return "Not currently streaming"
        case .arNotSupported:
            return "AR is not supported on this device"
        case .connectionFailed:
            return "Failed to connect to server"
        }
    }
}