import Foundation
import Starscream

class StreamingClient: NSObject {
    
    // MARK: - Properties
    
    weak var delegate: StreamingClientDelegate?
    
    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var connectionUptime: TimeInterval = 0
    
    private let relayURL: String
    private let apiKey: String
    private var webSocket: WebSocket?
    
    private var connectionStartTime: Date?
    private var reconnectionAttempts = 0
    private let maxReconnectionAttempts = 5
    private var reconnectionTimer: Timer?
    
    // Packet queue for buffering during disconnections
    private var packetQueue: [SpatialPacket] = []
    private let maxQueueSize = 1000
    private let sendQueue = DispatchQueue(label: "com.streamkit.sending", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init(relayURL: String, apiKey: String) {
        self.relayURL = relayURL
        self.apiKey = apiKey
        super.init()
    }
    
    // MARK: - Connection Management
    
    func connect() {
        guard connectionState == .disconnected else { return }
        
        updateConnectionState(.connecting)
        
        guard let url = URL(string: relayURL) else {
            delegate?.streamingClient(self, didEncounterError: StreamKitError.invalidConfiguration("Invalid relay URL"))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("streamkit-ios", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        
        webSocket = WebSocket(request: request)
        webSocket?.delegate = self
        webSocket?.connect()
    }
    
    func disconnect() {
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
        
        webSocket?.disconnect()
        webSocket = nil
        
        updateConnectionState(.disconnected)
        connectionStartTime = nil
        reconnectionAttempts = 0
        
        // Clear packet queue on manual disconnect
        sendQueue.async { [weak self] in
            self?.packetQueue.removeAll()
        }
    }
    
    // MARK: - Packet Sending
    
    func sendPacket(_ packet: SpatialPacket) {
        sendQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.connectionState == .connected {
                self.sendPacketImmediately(packet)
            } else {
                // Buffer packet for later sending
                self.bufferPacket(packet)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateConnectionState(_ newState: ConnectionState) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = newState
            
            if newState == .connected {
                self?.connectionStartTime = Date()
                self?.reconnectionAttempts = 0
            } else {
                self?.connectionStartTime = nil
            }
        }
    }
    
    private func sendPacketImmediately(_ packet: SpatialPacket) {
        do {
            let jsonData = try JSONEncoder().encode(packet)
            webSocket?.write(data: jsonData)
        } catch {
            delegate?.streamingClient(self, didEncounterError: error)
        }
    }
    
    private func bufferPacket(_ packet: SpatialPacket) {
        // Add to queue, removing oldest if at capacity
        if packetQueue.count >= maxQueueSize {
            packetQueue.removeFirst()
        }
        packetQueue.append(packet)
    }
    
    private func flushPacketQueue() {
        sendQueue.async { [weak self] in
            guard let self = self else { return }
            
            for packet in self.packetQueue {
                self.sendPacketImmediately(packet)
            }
            
            self.packetQueue.removeAll()
        }
    }
    
    private func scheduleReconnection() {
        guard reconnectionAttempts < maxReconnectionAttempts else {
            delegate?.streamingClient(self, didEncounterError: StreamKitError.connectionTimeout)
            return
        }
        
        updateConnectionState(.reconnecting)
        
        let delay = min(pow(2.0, Double(reconnectionAttempts)), 30.0) // Exponential backoff, max 30s
        reconnectionAttempts += 1
        
        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }
}

// MARK: - WebSocketDelegate

extension StreamingClient: WebSocketDelegate {
    
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(let headers):
            print("StreamingClient: Connected with headers: \(headers)")
            updateConnectionState(.connected)
            
            // Generate session ID or extract from server response
            let sessionID = UUID().uuidString
            delegate?.streamingClient(self, didConnect: sessionID)
            
            // Flush any queued packets
            flushPacketQueue()
            
        case .disconnected(let reason, let code):
            print("StreamingClient: Disconnected with reason: \(reason), code: \(code)")
            updateConnectionState(.disconnected)
            
            let error = NSError(domain: "StreamKitWebSocket", code: Int(code), userInfo: [
                NSLocalizedDescriptionKey: reason
            ])
            
            delegate?.streamingClient(self, didDisconnect: error)
            
            // Attempt reconnection unless it was a manual disconnect
            if code != CloseCode.normal.rawValue && code != CloseCode.goingAway.rawValue {
                scheduleReconnection()
            }
            
        case .text(let string):
            print("StreamingClient: Received text: \(string)")
            // Handle server messages if needed
            
        case .binary(let data):
            print("StreamingClient: Received binary data of size: \(data.count)")
            // Handle binary server messages if needed
            
        case .ping(_):
            break // Pong is handled automatically
            
        case .pong(_):
            break // Keep connection alive
            
        case .viabilityChanged(let isViable):
            print("StreamingClient: Viability changed: \(isViable)")
            if !isViable && connectionState == .connected {
                scheduleReconnection()
            }
            
        case .reconnectSuggested(let shouldReconnect):
            print("StreamingClient: Reconnect suggested: \(shouldReconnect)")
            if shouldReconnect {
                scheduleReconnection()
            }
            
        case .cancelled:
            print("StreamingClient: Connection cancelled")
            updateConnectionState(.disconnected)
            
        case .error(let error):
            print("StreamingClient: Error: \(String(describing: error))")
            updateConnectionState(.disconnected)
            
            if let error = error {
                delegate?.streamingClient(self, didEncounterError: error)
            }
            
            scheduleReconnection()
        }
    }
}