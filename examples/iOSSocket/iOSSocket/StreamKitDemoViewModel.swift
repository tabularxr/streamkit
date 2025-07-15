//
//  StreamKitDemoViewModel.swift
//  iOSSocket
//
//  Created by Moroti Oyeyemi on 7/14/25.
//

import Foundation
import SwiftUI
import Combine
import StreamKit

@available(iOS 16.0, *)
@MainActor
class StreamKitDemoViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var relayURL: String = "ws://localhost:8081/ws"
    @Published var apiKey: String = "demo-api-key"
    @Published var connectionStatus: String = "Disconnected"
    @Published var sessionID: String?
    @Published var isStreaming: Bool = false
    @Published var isPaused: Bool = false
    @Published var framesSent: Int = 0
    @Published var meshesSent: Int = 0
    @Published var compressionRatio: Double = 0.0
    @Published var connectionUptime: TimeInterval = 0
    @Published var totalDataSent: Int = 0
    @Published var bandwidth: Double = 0.0
    
    // MARK: - Private Properties
    
    private var streamKit: StreamKit?
    private var metricsTimer: Timer?
    private var lastDataSentSnapshot: Int = 0
    private var lastBandwidthUpdate: Date = Date()
    private var startTime: Date?
    
    // MARK: - Computed Properties
    
    var canStartStreaming: Bool {
        !relayURL.isEmpty && !apiKey.isEmpty && !isStreaming
    }
    
    var formattedUptime: String {
        let hours = Int(connectionUptime) / 3600
        let minutes = Int(connectionUptime) % 3600 / 60
        let seconds = Int(connectionUptime) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var formattedDataSent: String {
        let bytes = Double(totalDataSent)
        
        if bytes < 1024 {
            return String(format: "%.0f B", bytes)
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        } else {
            return String(format: "%.1f GB", bytes / (1024 * 1024 * 1024))
        }
    }
    
    var formattedBandwidth: String {
        if bandwidth < 1024 {
            return String(format: "%.0f B/s", bandwidth)
        } else if bandwidth < 1024 * 1024 {
            return String(format: "%.1f KB/s", bandwidth / 1024)
        } else {
            return String(format: "%.1f MB/s", bandwidth / (1024 * 1024))
        }
    }
    
    // MARK: - Initialization
    
    init() {
        setupStreamKit()
    }
    
    deinit {
        Task { @MainActor in
            stopMetricsTimer()
        }
        streamKit?.stopStreaming()
    }
    
    // MARK: - Public Methods
    
    func startStreaming() {
        guard canStartStreaming else { return }
        
        setupStreamKit()
        
        do {
            try streamKit?.startStreaming()
            // Don't set isStreaming here - wait for didStartStreaming delegate
            connectionStatus = "Connecting..."
            startTime = Date()
            resetMetrics()
            
        } catch {
            print("Failed to start streaming: \(error)")
            connectionStatus = "Error: \(error.localizedDescription)"
            isStreaming = false
            isPaused = false
        }
    }
    
    func stopStreaming() {
        guard isStreaming else { return }
        
        streamKit?.stopStreaming()
        // Don't set state here - wait for delegate callback
        // The didStopStreaming delegate will update the state
    }
    
    func pauseStreaming() {
        guard isStreaming && !isPaused else { return }
        
        streamKit?.pauseStreaming()
        isPaused = true
    }
    
    func resumeStreaming() {
        guard isStreaming && isPaused else { return }
        
        streamKit?.resumeStreaming()
        isPaused = false
    }
    
    func startMetricsTimer() {
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
    }
    
    func stopMetricsTimer() {
        metricsTimer?.invalidate()
        metricsTimer = nil
    }
    
    // MARK: - Private Methods
    
    private func setupStreamKit() {
        // Create StreamKit instance with current settings
        streamKit = StreamKit(relayURL: relayURL, apiKey: apiKey)
        streamKit?.delegate = self
        
        // Configure compression and buffer settings
        streamKit?.configure(compression: .medium, bufferSize: 100)
        
        // Update connection status
        connectionStatus = "Disconnected"
    }
    
    private func updateMetrics() {
        if let startTime = startTime {
            connectionUptime = Date().timeIntervalSince(startTime)
        }
        
        // Get metrics from StreamKit if available
        if let streamKit = streamKit {
            let metrics = streamKit.sessionMetrics
            framesSent = metrics.framesSent
            meshesSent = metrics.meshesSent
            compressionRatio = metrics.compressionRatio
            connectionUptime = metrics.connectionUptime
        }
        
        // Calculate bandwidth
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastBandwidthUpdate)
        let dataDelta = totalDataSent - lastDataSentSnapshot
        
        if timeDelta > 0 {
            bandwidth = Double(dataDelta) / timeDelta
        }
        
        lastDataSentSnapshot = totalDataSent
        lastBandwidthUpdate = now
    }
    
    private func resetMetrics() {
        framesSent = 0
        meshesSent = 0
        compressionRatio = 0.0
        connectionUptime = 0
        totalDataSent = 0
        bandwidth = 0.0
        lastDataSentSnapshot = 0
        lastBandwidthUpdate = Date()
    }
    
}


// MARK: - StreamKitDelegate

@available(iOS 16.0, *)
extension StreamKitDemoViewModel: StreamKitDelegate {
    
    func streamKit(_ streamKit: StreamKit, didConnect sessionID: String) {
        connectionStatus = "Connected"
        self.sessionID = sessionID
        print("StreamKit connected with session ID: \(sessionID)")
    }
    
    func streamKit(_ streamKit: StreamKit, didDisconnect error: Error?) {
        connectionStatus = "Disconnected"
        self.sessionID = nil
        isStreaming = false
        isPaused = false
        startTime = nil
        
        if let error = error {
            print("StreamKit disconnected with error: \(error)")
        } else {
            print("StreamKit disconnected")
        }
    }
    
    func streamKit(_ streamKit: StreamKit, didStartStreaming sessionID: String) {
        connectionStatus = "Streaming"
        isStreaming = true
        isPaused = false
        print("StreamKit started streaming")
    }
    
    func streamKit(_ streamKit: StreamKit, didStopStreaming sessionID: String) {
        connectionStatus = "Connected"
        isStreaming = false
        isPaused = false
        startTime = nil
        print("StreamKit stopped streaming")
    }
    
    func streamKit(_ streamKit: StreamKit, didPauseStreaming sessionID: String) {
        print("StreamKit paused streaming")
    }
    
    func streamKit(_ streamKit: StreamKit, didResumeStreaming sessionID: String) {
        print("StreamKit resumed streaming")
    }
    
    func streamKit(_ streamKit: StreamKit, didSendFrame frameNumber: Int) {
        // Frame count and data metrics are handled by SessionMetrics
        // Update total data sent from actual StreamKit metrics
        let metrics = streamKit.sessionMetrics
        totalDataSent = metrics.framesSent * 2048 // Estimate based on frame count
    }
    
    func streamKit(_ streamKit: StreamKit, didEncounterError error: StreamKitError) {
        connectionStatus = "Error: \(error.localizedDescription)"
        print("StreamKit encountered error: \(error)")
    }
}