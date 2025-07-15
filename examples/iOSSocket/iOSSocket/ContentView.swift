//
//  ContentView.swift
//  iOSSocket
//
//  Created by Moroti Oyeyemi on 7/14/25.
//

import SwiftUI

@available(iOS 16.0, *)
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
                    
                    Text("Spatial Data Streaming Test")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                // Connection Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Connection Settings")
                        .font(.headline)
                    
                    HStack {
                        Text("Relay URL:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    TextField("ws://localhost:8081/ws", text: $viewModel.relayURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    HStack {
                        Text("API Key:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    TextField("Enter API Key", text: $viewModel.apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal)
                
                // Connection Status
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connection Status")
                        .font(.headline)
                    
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)
                        
                        Text(viewModel.connectionStatus)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                    
                    if let sessionID = viewModel.sessionID {
                        Text("Session: \(sessionID)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Metrics Display
                VStack(alignment: .leading, spacing: 12) {
                    Text("Live Metrics")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        MetricCard(title: "Frames Sent", value: "\(viewModel.framesSent)")
                        MetricCard(title: "Meshes Sent", value: "\(viewModel.meshesSent)")
                        MetricCard(title: "Uptime", value: viewModel.formattedUptime)
                        MetricCard(title: "Compression", value: String(format: "%.1f%%", viewModel.compressionRatio * 100))
                        MetricCard(title: "Data Sent", value: viewModel.formattedDataSent)
                        MetricCard(title: "Bandwidth", value: viewModel.formattedBandwidth)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Control Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        if viewModel.isStreaming {
                            viewModel.stopStreaming()
                        } else {
                            viewModel.startStreaming()
                        }
                    }) {
                        HStack {
                            Image(systemName: viewModel.isStreaming ? "stop.fill" : "play.fill")
                            Text(viewModel.isStreaming ? "Stop Streaming" : "Start Streaming")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isStreaming ? Color.red : Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(!viewModel.canStartStreaming)
                    
                    if viewModel.isStreaming {
                        Button(action: {
                            if viewModel.isPaused {
                                viewModel.resumeStreaming()
                            } else {
                                viewModel.pauseStreaming()
                            }
                        }) {
                            HStack {
                                Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                                Text(viewModel.isPaused ? "Resume" : "Pause")
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .onAppear {
            viewModel.startMetricsTimer()
        }
        .onDisappear {
            viewModel.stopMetricsTimer()
        }
    }
    
    private var statusColor: Color {
        switch viewModel.connectionStatus {
        case "Connected":
            return .green
        case "Connecting", "Reconnecting":
            return .orange
        case "Disconnected":
            return .red
        default:
            return .gray
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}