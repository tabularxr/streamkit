import SwiftUI
import ARKit
import StreamKit

@available(iOS 16.0, visionOS 1.0, *)
struct ContentView: View {
    @StateObject private var viewModel = StreamKitDemoViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack {
                    Text("StreamKit Demo")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Spatial Data Streaming")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Connection Status
                HStack {
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 12, height: 12)
                    
                    Text(connectionStatusText)
                        .font(.headline)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Session Info
                if let sessionID = viewModel.sessionID {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(sessionID)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                // Metrics
                VStack(spacing: 16) {
                    HStack {
                        MetricView(
                            title: "Frames Sent",
                            value: "\(viewModel.framesSent)",
                            color: .blue
                        )
                        
                        Spacer()
                        
                        MetricView(
                            title: "Meshes Sent",
                            value: "\(viewModel.meshesSent)",
                            color: .green
                        )
                    }
                    
                    HStack {
                        MetricView(
                            title: "Compression",
                            value: String(format: "%.1f%%", viewModel.compressionRatio * 100),
                            color: .orange
                        )
                        
                        Spacer()
                        
                        MetricView(
                            title: "Uptime",
                            value: String(format: "%.1fs", viewModel.connectionUptime),
                            color: .purple
                        )
                    }
                }
                .padding()
                
                // Controls
                VStack(spacing: 12) {
                    if viewModel.isStreaming {
                        Button(action: {
                            if viewModel.isPaused {
                                viewModel.resumeStreaming()
                            } else {
                                viewModel.pauseStreaming()
                            }
                        }) {
                            Text(viewModel.isPaused ? "Resume" : "Pause")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        Button(action: viewModel.stopStreaming) {
                            Text("Stop Streaming")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    } else {
                        Button(action: viewModel.startStreaming) {
                            Text("Start Streaming")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(!viewModel.isARKitSupported)
                    }
                }
                .padding()
                
                // Error Display
                if let error = viewModel.lastError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Error")
                            .font(.headline)
                            .foregroundColor(.red)
                        
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.checkARKitSupport()
        }
    }
    
    private var connectionColor: Color {
        switch viewModel.connectionState {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .orange
        case .disconnected:
            return .red
        }
    }
    
    private var connectionStatusText: String {
        switch viewModel.connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .reconnecting:
            return "Reconnecting..."
        case .disconnected:
            return "Disconnected"
        }
    }
}

struct MetricView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        ContentView()
    } else {
        Text("iOS 16.0+ required")
    }
}