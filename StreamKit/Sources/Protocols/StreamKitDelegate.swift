import Foundation

// MARK: - StreamKit Delegate Protocol

@available(iOS 16.0, visionOS 1.0, *)
public protocol StreamKitDelegate: AnyObject {
    
    /// Called when StreamKit successfully connects to the relay server
    /// - Parameters:
    ///   - streamKit: The StreamKit instance
    ///   - sessionID: Unique identifier for this streaming session
    func streamKit(_ streamKit: StreamKit, didConnect sessionID: String)
    
    /// Called when StreamKit disconnects from the relay server
    /// - Parameters:
    ///   - streamKit: The StreamKit instance
    ///   - error: Error that caused disconnection, if any
    func streamKit(_ streamKit: StreamKit, didDisconnect error: Error?)
    
    /// Called when streaming starts successfully
    /// - Parameters:
    ///   - streamKit: The StreamKit instance
    ///   - sessionID: Unique identifier for this streaming session
    func streamKit(_ streamKit: StreamKit, didStartStreaming sessionID: String)
    
    /// Called when streaming stops
    /// - Parameters:
    ///   - streamKit: The StreamKit instance
    ///   - sessionID: Unique identifier for the session that stopped
    func streamKit(_ streamKit: StreamKit, didStopStreaming sessionID: String)
    
    /// Called when streaming is paused
    /// - Parameters:
    ///   - streamKit: The StreamKit instance
    ///   - sessionID: Unique identifier for the paused session
    func streamKit(_ streamKit: StreamKit, didPauseStreaming sessionID: String)
    
    /// Called when streaming resumes from pause
    /// - Parameters:
    ///   - streamKit: The StreamKit instance
    ///   - sessionID: Unique identifier for the resumed session
    func streamKit(_ streamKit: StreamKit, didResumeStreaming sessionID: String)
    
    /// Called when a frame (pose) is successfully sent
    /// - Parameters:
    ///   - streamKit: The StreamKit instance
    ///   - frameNumber: Sequential frame number
    func streamKit(_ streamKit: StreamKit, didSendFrame frameNumber: Int)
    
    /// Called when an error occurs during streaming
    /// - Parameters:
    ///   - streamKit: The StreamKit instance
    ///   - error: The error that occurred
    func streamKit(_ streamKit: StreamKit, didEncounterError error: StreamKitError)
}

// MARK: - Optional Delegate Methods

public extension StreamKitDelegate {
    func streamKit(_ streamKit: StreamKit, didConnect sessionID: String) {}
    func streamKit(_ streamKit: StreamKit, didDisconnect error: Error?) {}
    func streamKit(_ streamKit: StreamKit, didStartStreaming sessionID: String) {}
    func streamKit(_ streamKit: StreamKit, didStopStreaming sessionID: String) {}
    func streamKit(_ streamKit: StreamKit, didPauseStreaming sessionID: String) {}
    func streamKit(_ streamKit: StreamKit, didResumeStreaming sessionID: String) {}
    func streamKit(_ streamKit: StreamKit, didSendFrame frameNumber: Int) {}
    func streamKit(_ streamKit: StreamKit, didEncounterError error: StreamKitError) {}
}

// MARK: - Internal Delegate Protocols

protocol ARSessionManagerDelegate: AnyObject {
    func arSessionManager(_ manager: ARSessionManager, didUpdate pose: PoseData, frameNumber: Int)
    func arSessionManager(_ manager: ARSessionManager, didUpdate meshData: MeshData, frameNumber: Int)
    func arSessionManager(_ manager: ARSessionManager, didEncounterError error: Error)
}

protocol StreamingClientDelegate: AnyObject {
    func streamingClient(_ client: StreamingClient, didConnect sessionID: String)
    func streamingClient(_ client: StreamingClient, didDisconnect error: Error?)
    func streamingClient(_ client: StreamingClient, didEncounterError error: Error)
}