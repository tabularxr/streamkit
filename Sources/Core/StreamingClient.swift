import Foundation
import Network

/// WebSocket client for streaming spatial data
public class StreamingClient: NSObject {
    
    // WebSocket connection
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    
    // Connection properties
    private let serverURL: String
    private let apiKey: String?
    private var sessionId: String?
    
    // Connection state
    public private(set) var connectionState: ConnectionState = .disconnected {
        didSet {
            delegate?.streamingClient(self, didChangeState: connectionState)
        }
    }
    
    // Message queue for offline buffering
    private var messageQueue: [WSMessage] = []
    private let maxQueueSize = 1000
    
    // Reconnection properties
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private let baseReconnectDelay: TimeInterval = 1.0
    
    // Ping/pong for keep-alive
    private var pingTimer: Timer?
    private let pingInterval: TimeInterval = 30.0
    
    // Delegate
    public weak var delegate: StreamingClientDelegate?
    
    // Statistics
    public private(set) var messagesSent: Int = 0
    public private(set) var messagesReceived: Int = 0
    public private(set) var bytesTransmitted: Int64 = 0
    
    public init(serverURL: String, apiKey: String? = nil) {
        self.serverURL = serverURL
        self.apiKey = apiKey
        super.init()
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        
        self.urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }
    
    // MARK: - Connection Management
    
    public func connect(sessionId: String) {
        self.sessionId = sessionId
        
        guard connectionState == .disconnected || connectionState == .failed else {
            print("[StreamingClient] Already connected or connecting")
            return
        }
        
        connectionState = .connecting
        reconnectAttempts = 0
        
        // Build WebSocket URL
        guard let url = buildWebSocketURL(sessionId: sessionId) else {
            connectionState = .failed
            delegate?.streamingClient(self, didFailWithError: StreamingError.invalidURL)
            return
        }
        
        // Create WebSocket request
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        // Add API key if provided
        if let apiKey = apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // Create WebSocket task
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start receiving messages
        receiveMessage()
        
        // Connection will be confirmed when we receive the first message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if self?.connectionState == .connecting {
                self?.connectionState = .connected
                self?.startPingTimer()
                self?.flushMessageQueue()
            }
        }
    }
    
    public func disconnect() {
        stopPingTimer()
        stopReconnectTimer()
        
        connectionState = .disconnected
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }
    
    // MARK: - Message Sending
    
    public func sendAnchorUpdate(_ update: AnchorUpdate) {
        do {
            let data = try JSONEncoder().encode(update)
            let message = WSMessage(
                type: "anchor_update",
                sessionId: sessionId,
                data: data,
                traceId: UUID().uuidString
            )
            sendMessage(message)
        } catch {
            delegate?.streamingClient(self, didFailWithError: error)
        }
    }
    
    public func sendMeshUpdate(_ update: MeshUpdate) {
        do {
            let data = try JSONEncoder().encode(update)
            let message = WSMessage(
                type: "mesh_update",
                sessionId: sessionId,
                data: data,
                traceId: UUID().uuidString
            )
            sendMessage(message)
        } catch {
            delegate?.streamingClient(self, didFailWithError: error)
        }
    }
    
    private func sendMessage(_ message: WSMessage) {
        guard connectionState == .connected else {
            // Queue message if not connected
            queueMessage(message)
            return
        }
        
        do {
            let data = try JSONEncoder().encode(message)
            let wsMessage = URLSessionWebSocketTask.Message.data(data)
            
            webSocketTask?.send(wsMessage) { [weak self] error in
                if let error = error {
                    print("[StreamingClient] Send error: \(error)")
                    self?.handleConnectionError(error)
                } else {
                    self?.messagesSent += 1
                    self?.bytesTransmitted += Int64(data.count)
                }
            }
        } catch {
            delegate?.streamingClient(self, didFailWithError: error)
        }
    }
    
    // MARK: - Message Receiving
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.handleMessage(message)
                // Continue receiving
                self.receiveMessage()
                
            case .failure(let error):
                print("[StreamingClient] Receive error: \(error)")
                self.handleConnectionError(error)
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            messagesReceived += 1
            
            do {
                let wsMessage = try JSONDecoder().decode(WSMessage.self, from: data)
                
                switch wsMessage.type {
                case "pong":
                    // Keep-alive response
                    break
                    
                case "error":
                    if let errorData = wsMessage.data,
                       let errorInfo = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                       let errorMessage = errorInfo["message"] as? String {
                        delegate?.streamingClient(self, didReceiveError: errorMessage)
                    }
                    
                case "anchor_update", "mesh_update":
                    // Forward to delegate
                    delegate?.streamingClient(self, didReceiveMessage: wsMessage)
                    
                default:
                    print("[StreamingClient] Unknown message type: \(wsMessage.type)")
                }
                
            } catch {
                print("[StreamingClient] Failed to decode message: \(error)")
            }
            
        case .string(let string):
            print("[StreamingClient] Received string message: \(string)")
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Queue Management
    
    private func queueMessage(_ message: WSMessage) {
        guard messageQueue.count < maxQueueSize else {
            print("[StreamingClient] Message queue full, dropping oldest message")
            messageQueue.removeFirst()
            return
        }
        
        messageQueue.append(message)
        
        // Attempt reconnection if needed
        if connectionState == .disconnected || connectionState == .failed {
            attemptReconnection()
        }
    }
    
    private func flushMessageQueue() {
        guard connectionState == .connected else { return }
        
        let messages = messageQueue
        messageQueue.removeAll()
        
        for message in messages {
            sendMessage(message)
        }
        
        if !messages.isEmpty {
            print("[StreamingClient] Flushed \(messages.count) queued messages")
        }
    }
    
    // MARK: - Reconnection Logic
    
    private func attemptReconnection() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("[StreamingClient] Max reconnection attempts reached")
            connectionState = .failed
            return
        }
        
        guard connectionState != .connecting && connectionState != .connected else {
            return
        }
        
        connectionState = .reconnecting
        reconnectAttempts += 1
        
        // Exponential backoff
        let delay = baseReconnectDelay * pow(2.0, Double(reconnectAttempts - 1))
        
        print("[StreamingClient] Attempting reconnection \(reconnectAttempts)/\(maxReconnectAttempts) in \(delay)s")
        
        stopReconnectTimer()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self, let sessionId = self.sessionId else { return }
            self.connect(sessionId: sessionId)
        }
    }
    
    private func handleConnectionError(_ error: Error) {
        stopPingTimer()
        
        if connectionState == .connected || connectionState == .connecting {
            attemptReconnection()
        }
    }
    
    // MARK: - Keep-Alive
    
    private func startPingTimer() {
        stopPingTimer()
        
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    private func sendPing() {
        let message = WSMessage(type: "ping", sessionId: sessionId)
        sendMessage(message)
    }
    
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    // MARK: - URL Building
    
    private func buildWebSocketURL(sessionId: String) -> URL? {
        guard var components = URLComponents(string: serverURL) else { return nil }
        
        // Convert http/https to ws/wss
        if components.scheme == "http" {
            components.scheme = "ws"
        } else if components.scheme == "https" {
            components.scheme = "wss"
        }
        
        // Add path and query parameters
        components.path = "/api/v1/ws"
        components.queryItems = [
            URLQueryItem(name: "session_id", value: sessionId)
        ]
        
        return components.url
    }
    
    deinit {
        disconnect()
    }
}

// MARK: - URLSessionWebSocketDelegate

extension StreamingClient: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[StreamingClient] WebSocket connected")
        connectionState = .connected
        reconnectAttempts = 0
        startPingTimer()
        flushMessageQueue()
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[StreamingClient] WebSocket closed: \(closeCode)")
        handleConnectionError(StreamingError.connectionClosed(closeCode))
    }
}

// MARK: - Delegate Protocol

public protocol StreamingClientDelegate: AnyObject {
    func streamingClient(_ client: StreamingClient, didChangeState state: ConnectionState)
    func streamingClient(_ client: StreamingClient, didReceiveMessage message: WSMessage)
    func streamingClient(_ client: StreamingClient, didReceiveError error: String)
    func streamingClient(_ client: StreamingClient, didFailWithError error: Error)
}

// MARK: - Errors

public enum StreamingError: LocalizedError {
    case invalidURL
    case connectionClosed(URLSessionWebSocketTask.CloseCode)
    case encodingFailed
    case decodingFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .connectionClosed(let code):
            return "Connection closed with code: \(code)"
        case .encodingFailed:
            return "Failed to encode message"
        case .decodingFailed:
            return "Failed to decode message"
        }
    }
}