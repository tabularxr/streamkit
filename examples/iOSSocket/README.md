# StreamKit iOS Demo App

A basic iOS demo application for testing the StreamKit spatial data streaming package.

## Features

- **Simple UI**: Clean SwiftUI interface with connection controls
- **Live Metrics**: Real-time display of streaming metrics including:
  - Frames sent
  - Meshes sent
  - Connection uptime
  - Compression ratio
  - Data sent
  - Bandwidth usage
- **Connection Management**: Start/stop/pause/resume streaming controls
- **Pre-configured**: Default relay URL set to `ws://localhost:8081/ws` (matches relay service)

## Requirements

- iOS 16.0 or later
- Xcode 14.0 or later
- Relay service running on port 8081
- STAG service running on port 8080

## Setup

1. **Start the services**:
   ```bash
   # Start relay service (should be on port 8081)
   cd /path/to/tabular/packages/relays
   go run cmd/relay/main.go
   
   # Start STAG service (should be on port 8080)  
   cd /path/to/tabular/packages/stag
   make run
   ```

2. **Open the Xcode project**:
   ```bash
   open iOSSocket.xcodeproj
   ```

3. **Build and run** on device or simulator

## Usage

1. **Configure Connection**:
   - The relay URL is pre-filled with `ws://localhost:8081/ws`
   - Enter an API key (any string works for testing)

2. **Start Streaming**:
   - Press "Start Streaming" to begin
   - Watch the connection status change to "Connected" then "Streaming"
   - Monitor live metrics in the grid

3. **Control Streaming**:
   - Use "Pause/Resume" to control streaming
   - Use "Stop Streaming" to disconnect

## Mock Implementation

Currently uses a mock StreamKit implementation that simulates:
- Connection process with realistic delays
- Frame and mesh sending with random intervals
- Realistic metrics (bandwidth, compression ratios)
- Connection state management

## Integration with Real StreamKit

To use the actual StreamKit package:

1. **Add Package Dependency**:
   - In Xcode: File → Add Package Dependencies
   - Add local package: `../../../StreamKit`

2. **Update Import**:
   ```swift
   // In StreamKitDemoViewModel.swift, uncomment:
   import StreamKit
   ```

3. **Replace Mock**:
   ```swift
   // Change setupStreamKit() to use real StreamKit:
   streamKit = StreamKit(relayURL: relayURL, apiKey: apiKey)
   ```

## Metrics Explained

- **Frames Sent**: Number of pose/position frames transmitted
- **Meshes Sent**: Number of 3D mesh objects transmitted  
- **Uptime**: Connection duration in HH:MM:SS format
- **Compression**: Compression ratio as percentage
- **Data Sent**: Total bytes transmitted (B/KB/MB/GB)
- **Bandwidth**: Current transmission rate (B/s, KB/s, MB/s)

## Troubleshooting

- **Connection fails**: Ensure relay service is running on port 8081
- **No metrics**: Check that STAG service is running on port 8080
- **Build errors**: Ensure iOS 16.0+ deployment target
- **Simulator issues**: Some AR features may require physical device

## File Structure

```
iOSSocket/
├── iOSSocketApp.swift          # App entry point
├── ContentView.swift           # Main UI
├── StreamKitDemoViewModel.swift # Business logic & StreamKit integration
├── Info.plist                  # Camera permissions
└── README.md                   # This file
```