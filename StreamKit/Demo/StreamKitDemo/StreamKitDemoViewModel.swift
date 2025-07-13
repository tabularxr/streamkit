import Foundation
import SwiftUI
import ARKit
import StreamKit

@available(iOS 16.0, visionOS 1.0, *)
@MainActor
class StreamKitDemoViewModel: ObservableObject, StreamKitDelegate {
    
    // MARK: - Published Properties
    
    @Published var isStreaming = false
    @Published var isPaused = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var sessionID: String?
    @Published var framesSent = 0
    @Published var meshesSent = 0
    @Published var compressionRatio: Double = 0.0
    @Published var connectionUptime: TimeInterval = 0.0
    @Published var lastError: StreamKitError?
    @Published var isARKitSupported = false
    
    // MARK: - Private Properties
    
    private var streamKit: StreamKit?
    private var metricsTimer: Timer?
    
    // Configuration
    private let relayURL = "ws://localhost:8080/ws"
    private let apiKey = "demo-api-key"
    
    // MARK: - Initialization
    
    init() {
        setupStreamKit()
    }
    
    deinit {
        metricsTimer?.invalidate()
        streamKit?.stopStreaming()
    }
    
    // MARK: - Setup
    
    private func setupStreamKit() {
        streamKit = StreamKit(relayURL: relayURL, apiKey: apiKey)
        streamKit?.delegate = self
        streamKit?.configure(compression: .medium, bufferSize: 100)
    }
    
    func checkARKitSupport() {
        isARKitSupported = ARWorldTrackingConfiguration.isSupported
    }
    
    // MARK: - Streaming Controls
    
    func startStreaming() {
        guard let streamKit = streamKit else { return }
        
        do {
            try streamKit.startStreaming()
            isStreaming = true
            isPaused = false
            lastError = nil
            startMetricsTimer()
        } catch {
            if let streamKitError = error as? StreamKitError {
                lastError = streamKitError
            } else {
                lastError = .arSessionError(error)
            }
        }
    }
    
    func stopStreaming() {
        streamKit?.stopStreaming()
        isStreaming = false
        isPaused = false
        sessionID = nil
        stopMetricsTimer()
        resetMetrics()
    }
    
    func pauseStreaming() {
        streamKit?.pauseStreaming()
        isPaused = true
    }
    
    func resumeStreaming() {
        streamKit?.resumeStreaming()
        isPaused = false
    }
    
    // MARK: - Metrics
    
    private func startMetricsTimer() {
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                self.updateMetrics()
            }
        }
    }
    
    private func stopMetricsTimer() {
        metricsTimer?.invalidate()
        metricsTimer = nil
    }
    
    private func updateMetrics() {
        guard let streamKit = streamKit else { return }
        
        let metrics = streamKit.sessionMetrics
        framesSent = metrics.framesSent
        meshesSent = metrics.meshesSent
        compressionRatio = metrics.compressionRatio
        connectionUptime = metrics.connectionUptime
        connectionState = streamKit.connectionState
    }
    
    private func resetMetrics() {
        framesSent = 0
        meshesSent = 0
        compressionRatio = 0.0
        connectionUptime = 0.0
    }
    
    // MARK: - StreamKitDelegate
    
    func streamKit(_ streamKit: StreamKit, didConnect sessionID: String) {
        self.sessionID = sessionID
        connectionState = .connected
        print("StreamKit connected with session ID: \(sessionID)")
    }
    
    func streamKit(_ streamKit: StreamKit, didDisconnect error: Error?) {
        connectionState = .disconnected
        if let error = error {
            print("StreamKit disconnected with error: \(error)")
            lastError = .networkError(error)
        } else {
            print("StreamKit disconnected")
        }
    }
    
    func streamKit(_ streamKit: StreamKit, didStartStreaming sessionID: String) {
        self.sessionID = sessionID
        isStreaming = true
        print("StreamKit started streaming: \(sessionID)")
    }
    
    func streamKit(_ streamKit: StreamKit, didStopStreaming sessionID: String) {
        isStreaming = false
        isPaused = false
        print("StreamKit stopped streaming: \(sessionID)")
    }
    
    func streamKit(_ streamKit: StreamKit, didPauseStreaming sessionID: String) {
        isPaused = true
        print("StreamKit paused streaming: \(sessionID)")
    }
    
    func streamKit(_ streamKit: StreamKit, didResumeStreaming sessionID: String) {
        isPaused = false
        print("StreamKit resumed streaming: \(sessionID)")
    }
    
    func streamKit(_ streamKit: StreamKit, didSendFrame frameNumber: Int) {
        // Frame count is updated via metrics timer
        // Uncomment for debugging individual frames:
        // print("Frame sent: \(frameNumber)")
    }
    
    func streamKit(_ streamKit: StreamKit, didEncounterError error: StreamKitError) {
        lastError = error
        print("StreamKit error: \(error.localizedDescription)")
        
        // Handle specific errors
        switch error {
        case .connectionTimeout, .networkError:
            // Connection issues - could retry
            break
        case .arSessionError:
            // ARKit issues - might need to restart session
            break
        case .compressionError:
            // Compression issues - could reduce quality
            break
        default:
            break
        }
    }
}