import Foundation
import ARKit

@available(iOS 16.0, visionOS 1.0, *)
class ARSessionManager: NSObject {
    
    // MARK: - Properties
    
    weak var delegate: ARSessionManagerDelegate?
    
    private let arSession: ARSession
    private var frameNumber: Int = 0
    private var isSessionRunning = false
    
    // Frame rate control
    private var lastPoseTime: TimeInterval = 0
    private let poseFrameInterval: TimeInterval = 1.0 / 30.0 // 30 FPS
    
    // Mesh batching
    private var meshBuffer: [MeshData] = []
    private var lastMeshFlush: TimeInterval = 0
    private let meshFlushInterval: TimeInterval = 0.1 // 100ms
    
    // MARK: - Initialization
    
    override init() {
        self.arSession = ARSession()
        super.init()
        self.arSession.delegate = self
    }
    
    // MARK: - Session Management
    
    func startSession() throws {
        guard ARWorldTrackingConfiguration.isSupported else {
            throw StreamKitError.arNotSupported
        }
        
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable scene reconstruction for LiDAR devices
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
        // Enable plane detection for better tracking
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Enable auto focus for better quality
        configuration.isAutoFocusEnabled = true
        
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
        frameNumber = 0
    }
    
    func stopSession() {
        arSession.pause()
        isSessionRunning = false
        frameNumber = 0
        meshBuffer.removeAll()
    }
    
    func pauseSession() {
        arSession.pause()
        isSessionRunning = false
    }
    
    func resumeSession() {
        guard !isSessionRunning else { return }
        
        let configuration = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.isAutoFocusEnabled = true
        
        arSession.run(configuration)
        isSessionRunning = true
    }
    
    // MARK: - Private Methods
    
    private func shouldSendPose(at timestamp: TimeInterval) -> Bool {
        return timestamp - lastPoseTime >= poseFrameInterval
    }
    
    private func shouldFlushMeshes(at timestamp: TimeInterval) -> Bool {
        return timestamp - lastMeshFlush >= meshFlushInterval && !meshBuffer.isEmpty
    }
    
    private func flushMeshBuffer() {
        let timestamp = Date().timeIntervalSince1970
        
        for meshData in meshBuffer {
            delegate?.arSessionManager(self, didUpdate: meshData, frameNumber: frameNumber)
        }
        
        meshBuffer.removeAll()
        lastMeshFlush = timestamp
    }
}