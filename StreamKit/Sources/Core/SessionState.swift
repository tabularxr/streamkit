import Foundation

class SessionState {
    
    // MARK: - Properties
    
    private(set) var sessionID: String = ""
    private(set) var framesSent: Int = 0
    private(set) var meshesSent: Int = 0
    private(set) var startTime: Date?
    
    var bufferSize: Int = 100
    
    private let lock = NSLock()
    
    // MARK: - Session Management
    
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        sessionID = UUID().uuidString
        framesSent = 0
        meshesSent = 0
        startTime = Date()
    }
    
    internal func setSessionID(_ newSessionID: String) {
        lock.lock()
        defer { lock.unlock() }
        
        sessionID = newSessionID
        if startTime == nil {
            startTime = Date()
        }
    }
    
    // MARK: - Counters
    
    internal func incrementFramesSent() {
        lock.lock()
        defer { lock.unlock() }
        
        framesSent += 1
    }
    
    internal func incrementMeshesSent() {
        lock.lock()
        defer { lock.unlock() }
        
        meshesSent += 1
    }
    
    // MARK: - Statistics
    
    var sessionDuration: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        
        guard let startTime = startTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    var averageFrameRate: Double {
        lock.lock()
        defer { lock.unlock() }
        
        let duration = sessionDuration
        guard duration > 0 else { return 0 }
        return Double(framesSent) / duration
    }
    
    var averageMeshRate: Double {
        lock.lock()
        defer { lock.unlock() }
        
        let duration = sessionDuration
        guard duration > 0 else { return 0 }
        return Double(meshesSent) / duration
    }
}