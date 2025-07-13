# StreamKit Test App

A comprehensive iOS test application for validating the StreamKit SDK's end-to-end functionality. Built with SwiftUI (iOS 18+), this app provides real-time AR scanning, streaming metrics, logging, and STAG verification capabilities.

## Features

### 🎯 Core Functionality
- **AR Scanning**: Live ARKit preview with mesh overlays and wireframe visualization
- **One-tap Streaming**: Start/stop/pause/resume streaming with visual feedback
- **Real-time Metrics**: FPS tracking, compression ratios, bandwidth monitoring
- **Live Logging**: Timestamped events with filtering and export capabilities
- **STAG Integration**: Query and verify streamed data in the STAG database

### 📊 Metrics Dashboard
- **Performance Tracking**: 30 FPS target monitoring with trend analysis
- **Compression Analytics**: Real-time compression ratio visualization (>80% target)
- **Bandwidth Monitoring**: Upload rate tracking in KB/s
- **Session Analytics**: Uptime, packet counts, error rates, success metrics
- **Connection Status**: Latency, reconnection attempts, connection history

### 🔍 Advanced Logging
- **Real-time Console**: Timestamped entries with type classification
- **Smart Filtering**: Filter by type (Pose, Mesh, Error, Network, etc.)
- **Search Capability**: Text search across messages and details
- **Export Options**: Text, CSV, and JSON export formats
- **Log Rotation**: Automatic management of log history (1000 entries max)

### ⚙️ Configuration
- **Relay Settings**: WebSocket URL and API key configuration
- **Compression Levels**: Low/Medium/High with performance descriptions
- **STAG Integration**: HTTP endpoint configuration for data verification
- **Advanced Options**: Auto-reconnect, verbose logging toggles
- **Connection Testing**: Built-in connectivity validation

## Requirements

- **iOS 18.0+** or **visionOS 2.0+**
- **LiDAR-capable device** (iPhone 12 Pro+, iPad Pro 2020+)
- **Xcode 16+** for development
- **Network connectivity** to Relay and STAG servers

## Installation

### Via Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/tabular/streamkit", from: "1.0.0")
]
```

### Local Development
1. Clone the StreamKit repository
2. Open `StreamKitTestApp/Package.swift` in Xcode
3. Build and run on a physical device with LiDAR

## Quick Start

### 1. Initial Setup
1. Launch the app (first-time setup wizard will appear)
2. Configure your Relay server URL: `ws://your-relay-server.com/ws/streamkit`
3. Enter your API key from the Tabular Console
4. Set STAG query endpoint: `http://your-stag-server.com/query`

### 2. Basic Streaming
1. Go to the **Scan** tab
2. Point device at environment to see AR mesh overlays
3. Tap **Start** to begin streaming (green button)
4. Monitor real-time metrics in the top status bar
5. Use **Pause/Resume** for session control
6. Tap **Stop** to end the session

### 3. Monitoring Performance
1. Switch to **Metrics** tab during streaming
2. View real-time FPS, compression, and bandwidth charts
3. Monitor session information and connection status
4. Check performance trends and success rates

### 4. Reviewing Logs
1. Open **Logs** tab to see all streaming events
2. Filter by type: Pose, Mesh, Error, Network, etc.
3. Search for specific events or error messages
4. Export logs for analysis (Text/CSV/JSON formats)

### 5. STAG Verification
1. After streaming, go to **STAG** tab
2. Tap **Verify in STAG** to query the database
3. Review found anchors and mesh count
4. Inspect individual pose anchors and metadata
5. Verify data integrity and compression results

## Configuration Reference

### Relay Server Settings
```json
{
  "relayURL": "ws://localhost:8080/ws/streamkit",
  "apiKey": "your-tabular-api-key-here",
  "autoReconnect": true
}
```

### Compression Levels
- **Low**: Faster compression (~60-70% ratio), best for real-time
- **Medium**: Balanced performance (~75-85% ratio), recommended default
- **High**: Best compression (~85-95% ratio), use when bandwidth limited

### Performance Targets
- **FPS**: 30+ poses per second
- **Compression**: >80% size reduction
- **Memory**: <50MB total footprint
- **Battery**: <10% impact per 5-minute session

## Testing Framework

The app includes comprehensive unit tests covering:

### Test Coverage Areas
- **Data Models**: StreamMetrics, LogEntry, QueryResult validation
- **State Management**: Session transitions, error handling
- **Stream Manager**: Configuration, logging, metrics calculation
- **STAG Service**: Query operations, result validation
- **Error Handling**: Recovery actions, error classification

### Running Tests
```bash
# From StreamKitTestApp directory
swift test

# Or via Xcode
# Product → Test (⌘U)
```

### Test Results Target
- **80%+ code coverage** across all modules
- **100% pass rate** for core functionality
- **Performance benchmarks** for memory and processing

## Troubleshooting

### Common Issues

**"ARKit not supported"**
- Ensure device has LiDAR capability
- Check iOS version compatibility (18.0+)
- Verify camera permissions in Settings

**Connection failures**
- Validate Relay server URL format (`ws://` or `wss://`)
- Check API key validity in Tabular Console
- Test network connectivity to server

**Poor performance**
- Lower compression level to reduce CPU load
- Reduce buffer size in advanced settings
- Check device thermal state and battery level

**No data in STAG**
- Verify streaming session completed successfully
- Check STAG server URL and connectivity
- Ensure session ID matches between Relay and STAG

### Debug Logging
Enable verbose logging in Configuration → Advanced Settings for detailed diagnostics:

```swift
// Example verbose log output
[14:32:15] Pose: Frame 142 sent (x: 1.23, y: 0.45, z: -2.10)
[14:32:15] Compression: Mesh compressed 1.2MB → 240KB (80% reduction)
[14:32:16] Network: Packet sent successfully (142 bytes)
```

## Architecture

### App Structure
```
StreamKitTestApp/
├── Models/           # Data structures and enums
├── Views/            # SwiftUI views and UI components
├── Services/         # Business logic and API services
├── ViewModels/       # View state management
└── Resources/        # Assets and configuration files
```

### Key Components
- **StreamManager**: Central coordinator for StreamKit SDK
- **STAGQueryService**: Handles database verification queries
- **ErrorHandler**: Comprehensive error recovery system
- **AppStateHandler**: Background/foreground state management

### Data Flow
```
ARKit → StreamManager → StreamKit SDK → Relay Server
  ↓         ↓              ↓               ↓
Metrics → Logs → UI Updates → STAG Storage
```

## Development

### Building from Source
1. Clone the repository
2. Ensure StreamKit SDK is in `../StreamKit`
3. Open in Xcode 16+
4. Select a physical device target
5. Build and run (⌘R)

### Contributing
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

### Custom Extensions
The app is designed for easy customization:

```swift
// Add custom metrics
extension StreamMetrics {
    var customMetric: Double {
        // Your calculation here
    }
}

// Add custom log types
extension LogEntry.LogType {
    static let custom = LogEntry.LogType.custom
}
```

## Success Criteria

### Validation Checklist
- ✅ Streams 5-minute session without drops (>95% success rate)
- ✅ Verifies STAG data (query returns >10 anchors post-stream)
- ✅ Achieves compression targets (>80% reduction logged)
- ✅ Runs on iOS 18 device without crashes
- ✅ Maintains <50MB memory footprint
- ✅ Battery impact <10% per 5-minute session

### Performance Benchmarks
- **Latency**: <100ms mesh compression
- **Throughput**: 30 FPS pose streaming
- **Reliability**: <5% packet loss under normal conditions
- **Recovery**: <3 second reconnection after network drop

## Support

- **Documentation**: [docs.tabularxr.com](https://docs.tabularxr.com)
- **Issues**: [GitHub Issues](https://github.com/tabular/streamkit/issues)
- **Community**: [Discord](https://discord.gg/tabular)
- **Email**: support@tabularxr.com

## License

StreamKit Test App is part of the Tabular platform. See LICENSE file for details.

---

*This app serves as the "hello world" for StreamKit—developers can fork it for custom testing scenarios and integration validation.*