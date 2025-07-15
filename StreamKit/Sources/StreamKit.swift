import Foundation
import ARKit
import Starscream
import SwiftProtobuf

// MARK: - Public API

/// Main StreamKit SDK class for capturing and streaming spatial data
@available(iOS 16.0, visionOS 1.0, *)
public class StreamKit: NSObject {
    
    // MARK: - Public Properties
    
    public weak var delegate: StreamKitDelegate?
    
    public var connectionState: ConnectionState {
        return streamingClient.connectionState
    }
    
    public var sessionMetrics: SessionMetrics {
        return SessionMetrics(
            sessionID: sessionState.sessionID,
            framesSent: sessionState.framesSent,
            meshesSent: sessionState.meshesSent,
            compressionRatio: compressionEngine.averageCompressionRatio,
            connectionUptime: streamingClient.connectionUptime
        )
    }
    
    public var currentSessionID: String? {
        return sessionState.sessionID
    }
    
    // MARK: - Private Properties
    
    private let arSessionManager: ARSessionManager
    private let streamingClient: StreamingClient
    private let compressionEngine: CompressionEngine
    private let packetBuilder: PacketBuilder
    internal let sessionState: SessionState
    
    private var isStreaming = false
    private var isPaused = false
    
    // MARK: - Initialization
    
    public init(relayURL: String, apiKey: String) {
        self.sessionState = SessionState()
        self.compressionEngine = CompressionEngine()
        self.packetBuilder = PacketBuilder()
        self.streamingClient = StreamingClient(relayURL: relayURL, apiKey: apiKey)
        self.arSessionManager = ARSessionManager()
        
        super.init()
        
        setupDelegates()
    }
    
    private func setupDelegates() {
        arSessionManager.delegate = self
        streamingClient.delegate = self
    }
    
    // MARK: - Configuration
    
    public func configure(compression: CompressionLevel = .medium, bufferSize: Int = 100) {
        compressionEngine.compressionLevel = compression
        sessionState.bufferSize = bufferSize
    }
    
    // MARK: - Session Management
    
    public func startStreaming() throws {
        guard !isStreaming else {
            throw StreamKitError.alreadyStreaming
        }
        
        // Check ARKit availability
        guard ARWorldTrackingConfiguration.isSupported else {
            throw StreamKitError.arNotSupported
        }
        
        // Start AR session
        try arSessionManager.startSession()
        
        // Connect to relay
        streamingClient.connect()
        
        isStreaming = true
        isPaused = false
        
        delegate?.streamKit(self, didStartStreaming: sessionState.sessionID)
    }
    
    public func stopStreaming() {
        guard isStreaming else { return }
        
        arSessionManager.stopSession()
        streamingClient.disconnect()
        
        isStreaming = false
        isPaused = false
        
        delegate?.streamKit(self, didStopStreaming: sessionState.sessionID)
        sessionState.reset()
    }
    
    public func pauseStreaming() {
        guard isStreaming && !isPaused else { return }
        
        arSessionManager.pauseSession()
        isPaused = true
        
        delegate?.streamKit(self, didPauseStreaming: sessionState.sessionID)
    }
    
    public func resumeStreaming() {
        guard isStreaming && isPaused else { return }
        
        arSessionManager.resumeSession()
        isPaused = false
        
        delegate?.streamKit(self, didResumeStreaming: sessionState.sessionID)
    }
}

// MARK: - ARSessionManagerDelegate

extension StreamKit: ARSessionManagerDelegate {
    func arSessionManager(_ manager: ARSessionManager, didUpdate pose: PoseData, frameNumber: Int) {
        guard isStreaming && !isPaused else { return }
        
        let packet = packetBuilder.buildPosePacket(
            sessionID: sessionState.sessionID,
            frameNumber: frameNumber,
            pose: pose
        )
        
        streamingClient.sendPacket(packet)
        sessionState.incrementFramesSent()
        
        delegate?.streamKit(self, didSendFrame: frameNumber)
    }
    
    func arSessionManager(_ manager: ARSessionManager, didUpdate meshData: MeshData, frameNumber: Int) {
        guard isStreaming && !isPaused else { return }
        
        // Compress mesh data
        compressionEngine.compressMesh(meshData) { [weak self] compressedMesh in
            guard let self = self else { return }
            
            let packet = self.packetBuilder.buildMeshPacket(
                sessionID: self.sessionState.sessionID,
                frameNumber: frameNumber,
                mesh: compressedMesh
            )
            
            self.streamingClient.sendPacket(packet)
            self.sessionState.incrementMeshesSent()
        }
    }
    
    func arSessionManager(_ manager: ARSessionManager, didEncounterError error: Error) {
        delegate?.streamKit(self, didEncounterError: .arSessionError(error))
    }
}

// MARK: - StreamingClientDelegate

extension StreamKit: StreamingClientDelegate {
    func streamingClient(_ client: StreamingClient, didConnect sessionID: String) {
        sessionState.setSessionID(sessionID)
        delegate?.streamKit(self, didConnect: sessionID)
    }
    
    func streamingClient(_ client: StreamingClient, didDisconnect error: Error?) {
        if let error = error {
            delegate?.streamKit(self, didDisconnect: error)
        }
    }
    
    func streamingClient(_ client: StreamingClient, didEncounterError error: Error) {
        delegate?.streamKit(self, didEncounterError: .networkError(error))
    }
}