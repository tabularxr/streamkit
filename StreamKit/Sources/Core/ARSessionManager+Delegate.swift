import Foundation
import ARKit

// MARK: - ARSessionDelegate

@available(iOS 16.0, visionOS 1.0, *)
extension ARSessionManager: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isSessionRunning else { return }
        
        let timestamp = Date().timeIntervalSince1970
        
        // Send poses at controlled frame rate (30 FPS)
        if shouldSendPose(at: timestamp) {
            let pose = PoseData(
                transform: frame.camera.transform,
                timestamp: timestamp
            )
            
            frameNumber += 1
            lastPoseTime = timestamp
            
            delegate?.arSessionManager(self, didUpdate: pose, frameNumber: frameNumber)
        }
        
        // Flush mesh buffer periodically
        if shouldFlushMeshes(at: timestamp) {
            flushMeshBuffer()
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        processMeshAnchors(anchors)
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        processMeshAnchors(anchors)
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        // Handle anchor removal if needed
        // For MVP, we'll focus on additions and updates
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        delegate?.arSessionManager(self, didEncounterError: error)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Handle interruption (e.g., phone call, app backgrounding)
        isSessionRunning = false
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Handle interruption end - session will auto-resume
        isSessionRunning = true
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        // Always attempt relocalization for better tracking
        return true
    }
    
    // MARK: - Private Mesh Processing
    
    private func processMeshAnchors(_ anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                let meshData = MeshData(meshAnchor: meshAnchor)
                
                // Buffer meshes for batched sending
                meshBuffer.append(meshData)
                
                // If buffer is getting large, flush immediately
                if meshBuffer.count >= 10 {
                    flushMeshBuffer()
                }
            }
        }
    }
}