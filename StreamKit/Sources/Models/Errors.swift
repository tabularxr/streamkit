import Foundation

// MARK: - StreamKit Errors

public enum StreamKitError: Error, LocalizedError {
    case alreadyStreaming
    case notStreaming
    case arNotSupported
    case arSessionError(Error)
    case networkError(Error)
    case compressionError(String)
    case invalidConfiguration(String)
    case connectionTimeout
    case authenticationFailed
    
    public var errorDescription: String? {
        switch self {
        case .alreadyStreaming:
            return "StreamKit is already streaming. Stop current session before starting a new one."
        case .notStreaming:
            return "StreamKit is not currently streaming."
        case .arNotSupported:
            return "ARKit World Tracking is not supported on this device."
        case .arSessionError(let error):
            return "ARKit session error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .compressionError(let message):
            return "Compression error: \(message)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .connectionTimeout:
            return "Connection to relay server timed out."
        case .authenticationFailed:
            return "Authentication with relay server failed. Check your API key."
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .alreadyStreaming:
            return "Multiple streaming sessions are not supported."
        case .notStreaming:
            return "No active streaming session found."
        case .arNotSupported:
            return "Device lacks required ARKit capabilities."
        case .arSessionError:
            return "ARKit encountered an internal error."
        case .networkError:
            return "Unable to communicate with relay server."
        case .compressionError:
            return "Failed to compress spatial data."
        case .invalidConfiguration:
            return "Configuration parameters are invalid."
        case .connectionTimeout:
            return "Network connection timed out."
        case .authenticationFailed:
            return "Invalid or expired API key."
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .alreadyStreaming:
            return "Call stopStreaming() before starting a new session."
        case .notStreaming:
            return "Call startStreaming() to begin a session."
        case .arNotSupported:
            return "This feature requires a device with LiDAR sensor."
        case .arSessionError:
            return "Restart the AR session or check device permissions."
        case .networkError:
            return "Check network connectivity and relay server status."
        case .compressionError:
            return "Try lowering compression level or check mesh data validity."
        case .invalidConfiguration:
            return "Review configuration parameters and try again."
        case .connectionTimeout:
            return "Check network connectivity and try again."
        case .authenticationFailed:
            return "Verify your API key in the Console dashboard."
        }
    }
}