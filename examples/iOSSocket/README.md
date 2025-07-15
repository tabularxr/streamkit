# iOSSocket - StreamKit Demo App

A complete iOS demo application showcasing the StreamKit spatial data streaming SDK with real ARKit integration.

## Features

- **Real StreamKit Integration**: Uses the actual StreamKit SDK for ARKit data capture and streaming
- **ARKit Spatial Data**: Captures and streams device pose data and LiDAR mesh information
- **Live Metrics**: Real-time display of streaming metrics including:
  - Frames sent (pose data)
  - Meshes sent (LiDAR mesh data) 
  - Connection uptime
  - Compression ratio
  - Data transmitted
  - Current bandwidth
- **Connection Management**: Start/stop/pause/resume streaming controls
- **Pre-configured**: Default relay URL set to `ws://localhost:8081/ws` (matches relay service)

## Requirements

- iOS 16.0 or later
- Xcode 15.0 or later
- Physical iOS device with LiDAR sensor (iPad Pro, iPhone Pro models)
- ARKit support
- Camera permissions
- Relay service running on port 8081
- STAG service running on port 8080

## Setup

1. **Start the backend services**:
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

3. **Configure code signing**:
   - Select your development team in Signing & Capabilities
   - Ensure bundle identifier matches your provisioning profile
   - Trust developer certificate on your iOS device

4. **Build and run** on physical device (simulator won't work for ARKit)

## Usage

1. **Configure Connection**:
   - The relay URL is pre-filled with `ws://localhost:8081/ws`
   - Enter an API key (any string works for testing)

2. **Grant Permissions**:
   - Allow camera access when prompted (required for ARKit)
   - Ensure device is in a well-lit environment for best tracking

3. **Start Streaming**:
   - Press "Start Streaming" to begin ARKit session and streaming
   - Watch the connection status change to "Connected" then "Streaming"
   - Monitor live metrics showing real spatial data transmission

4. **Control Streaming**:
   - Use "Pause/Resume" to control data streaming while keeping ARKit active
   - Use "Stop Streaming" to stop ARKit session and disconnect

## Implementation Details

This app uses the real StreamKit SDK with:
- **Local package dependency**: References `../../StreamKit` 
- **ARKit integration**: Captures device poses and LiDAR mesh data at 30 FPS
- **WebSocket streaming**: Real-time data transmission to relay service
- **Compression**: Automatic mesh compression for efficient bandwidth usage
- **Error handling**: Comprehensive error recovery and reconnection logic

## Metrics Explained

- **Frames Sent**: Number of device pose/position frames transmitted
- **Meshes Sent**: Number of LiDAR 3D mesh objects transmitted  
- **Uptime**: Connection duration in HH:MM:SS format
- **Compression**: Mesh compression ratio as percentage
- **Data Sent**: Total bytes transmitted (B/KB/MB/GB)
- **Bandwidth**: Current transmission rate (B/s, KB/s, MB/s)

## Troubleshooting

- **Connection fails**: Ensure relay service is running on port 8081
- **No metrics**: Check that STAG service is running on port 8080
- **Build errors**: Ensure iOS 16.0+ deployment target and valid code signing
- **ARKit errors**: Must run on physical device with LiDAR sensor
- **Package errors**: Reset Package Caches in Xcode if StreamKit dependencies fail
- **Entitlements errors**: Verify development team selection and bundle identifier

## File Structure

```
iOSSocket/
├── iOSSocket/
│   ├── iOSSocketApp.swift          # App entry point
│   ├── ContentView.swift           # Main SwiftUI interface
│   ├── StreamKitDemoViewModel.swift # StreamKit integration & business logic
│   ├── Info.plist                  # Bundle info & camera permissions
│   └── iOSSocket.entitlements      # Code signing entitlements
├── iOSSocket.xcodeproj/            # Xcode project with StreamKit dependency
└── README.md                       # This file
```