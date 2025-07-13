# StreamKit

StreamKit is the iOS SDK for capturing and streaming spatial data (poses + LiDAR meshes) to the Tabular spatial memory platform.

## Features

- **ARKit Integration**: Seamless capture of poses and LiDAR mesh data
- **Real-time Streaming**: WebSocket-based streaming to Relay servers
- **Compression**: Built-in mesh compression for efficient data transfer
- **Error Resilience**: Automatic reconnection and error recovery
- **Background Support**: Handles app backgrounding and interruptions
- **Performance Optimized**: 30 FPS pose streaming, batched mesh processing

## Requirements

- iOS 16.0+ or visionOS 1.0+
- Device with ARKit support
- LiDAR sensor (for mesh data)
- Network connectivity to Relay server

## Installation

### Swift Package Manager

Add StreamKit to your project via Xcode:

1. File → Add Package Dependencies
2. Enter: `https://github.com/tabular/streamkit`
3. Select version and add to target

### Manual Integration

1. Clone this repository
2. Drag `StreamKit.xcodeproj` into your Xcode project
3. Add StreamKit as a dependency to your target

## Quick Start

```swift
import StreamKit
import ARKit

class ViewController: UIViewController, StreamKitDelegate {
    private var streamKit: StreamKit!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize StreamKit
        streamKit = StreamKit(
            relayURL: "ws://your-relay-server.com/ws",
            apiKey: "your-api-key"
        )
        streamKit.delegate = self
        
        // Configure compression and buffering
        streamKit.configure(compression: .medium, bufferSize: 100)
    }
    
    @IBAction func startStreaming() {
        do {
            try streamKit.startStreaming()
        } catch {
            print("Failed to start streaming: \\(error)")
        }
    }
    
    @IBAction func stopStreaming() {
        streamKit.stopStreaming()
    }
    
    // MARK: - StreamKitDelegate
    
    func streamKit(_ streamKit: StreamKit, didConnect sessionID: String) {
        print("Connected with session: \\(sessionID)")
    }
    
    func streamKit(_ streamKit: StreamKit, didEncounterError error: StreamKitError) {
        print("StreamKit error: \\(error.localizedDescription)")
    }
}
```

## Configuration

### Compression Levels

```swift
streamKit.configure(compression: .low)    // Faster, larger files
streamKit.configure(compression: .medium) // Balanced (default)
streamKit.configure(compression: .high)   // Slower, smaller files
```

### Buffer Management

```swift
streamKit.configure(bufferSize: 50)   // Smaller buffer, less memory
streamKit.configure(bufferSize: 200)  // Larger buffer, more resilience
```

## API Reference

### StreamKit Class

#### Initialization
```swift
init(relayURL: String, apiKey: String)
```

#### Configuration
```swift
func configure(compression: CompressionLevel, bufferSize: Int)
```

#### Session Management
```swift
func startStreaming() throws
func stopStreaming()
func pauseStreaming()
func resumeStreaming()
```

#### Properties
```swift
var connectionState: ConnectionState { get }
var sessionMetrics: SessionMetrics { get }
var currentSessionID: String? { get }
```

### StreamKitDelegate Protocol

```swift
func streamKit(_ streamKit: StreamKit, didConnect sessionID: String)
func streamKit(_ streamKit: StreamKit, didDisconnect error: Error?)
func streamKit(_ streamKit: StreamKit, didStartStreaming sessionID: String)
func streamKit(_ streamKit: StreamKit, didStopStreaming sessionID: String)
func streamKit(_ streamKit: StreamKit, didSendFrame frameNumber: Int)
func streamKit(_ streamKit: StreamKit, didEncounterError error: StreamKitError)
```

## Error Handling

StreamKit provides comprehensive error handling through the `StreamKitError` enum:

- `.alreadyStreaming`: Attempted to start when already streaming
- `.arNotSupported`: Device doesn't support required ARKit features
- `.networkError`: Connection or communication issues
- `.compressionError`: Mesh compression failures
- `.authenticationFailed`: Invalid API key

```swift
func streamKit(_ streamKit: StreamKit, didEncounterError error: StreamKitError) {
    switch error {
    case .networkError(let networkError):
        // Handle connection issues
        break
    case .arSessionError(let arError):
        // Handle ARKit issues
        break
    default:
        // Handle other errors
        break
    }
}
```

## Performance Guidelines

### Optimal Performance
- Use `.medium` compression for balanced performance
- Keep buffer size between 50-200 packets
- Test on target devices with real network conditions

### Memory Management
- StreamKit automatically manages memory for mesh buffers
- Monitor `sessionMetrics` for performance insights
- Call `stopStreaming()` when not needed to free resources

### Battery Optimization
- Use `.low` compression on battery-powered devices
- Implement pause/resume for background scenarios
- Monitor thermal state and adjust accordingly

## Testing

Run the test suite:

```bash
./run_tests.sh
```

### Unit Tests
- 90%+ code coverage
- Mock ARKit components for CI/CD
- Comprehensive error scenario testing

### Integration Tests
- Real device testing required for ARKit
- Network resilience testing
- Performance benchmarking

### Demo Application
A complete demo app is included in the `Demo/` directory:

1. Open `Demo/StreamKitDemo.xcodeproj`
2. Run on a physical device with LiDAR
3. Test streaming to a local Relay server

## Architecture

StreamKit is built with a modular architecture:

- **ARSessionManager**: ARKit integration and data capture
- **CompressionEngine**: Mesh compression and optimization
- **StreamingClient**: WebSocket communication and reconnection
- **PacketBuilder**: Data serialization and validation
- **SessionState**: Session management and metrics

## Troubleshooting

### Common Issues

**"ARKit not supported"**
- Ensure device has ARKit capability
- Check iOS version compatibility
- Verify in Info.plist: `NSCameraUsageDescription`

**Connection failures**
- Verify Relay server URL and port
- Check API key validity
- Ensure network connectivity

**Performance issues**
- Lower compression level
- Reduce buffer size
- Check device thermal state

### Debug Logging

Enable detailed logging:

```swift
// Add this for debug builds
#if DEBUG
print("StreamKit Debug: \\(message)")
#endif
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

StreamKit is part of the Tabular platform. See LICENSE file for details.

## Support

- Documentation: [docs.tabularxr.com](https://docs.tabularxr.com)
- Issues: [GitHub Issues](https://github.com/tabular/streamkit/issues)
- Discord: [Tabular Community](https://discord.gg/tabular)