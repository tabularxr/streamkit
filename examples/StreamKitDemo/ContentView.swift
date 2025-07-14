import SwiftUI

@available(iOS 16.0, visionOS 1.0, *)
struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var streamManager = StreamManager()
    @State private var selectedTab = 0
    @State private var showingConfiguration = false
    
    var body: some View {
        Group {
            if appState.isFirstLaunch || appState.configuration.apiKey == "demo-api-key" {
                WelcomeView(showingConfiguration: $showingConfiguration)
            } else {
                mainTabView
            }
        }
        .sheet(isPresented: $showingConfiguration) {
            ConfigurationView()
                .environmentObject(appState)
        }
        .environmentObject(streamManager)
    }
    
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            ARScanningView()
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("Scan")
                }
                .tag(0)
            
            MetricsDashboardView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Metrics")
                }
                .tag(1)
            
            LogViewerView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle")
                    Text("Logs")
                }
                .tag(2)
            
            STAGQueryView()
                .tabItem {
                    Image(systemName: "externaldrive.connected.to.line.below")
                    Text("STAG")
                }
                .tag(3)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingConfiguration = true
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .onAppear {
            streamManager.configure(with: appState.configuration)
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    @Binding var showingConfiguration: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 20) {
                    Image(systemName: "arkit")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("StreamKit Demo")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Comprehensive spatial data streaming test app")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    FeatureRow(icon: "camera.fill", title: "AR Scanning", description: "Live ARKit preview with mesh overlays and streaming controls")
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Real-time Metrics", description: "FPS tracking, compression ratios, bandwidth monitoring")
                    FeatureRow(icon: "list.bullet.rectangle", title: "Live Logging", description: "Timestamped events with filtering and export")
                    FeatureRow(icon: "externaldrive.connected.to.line.below", title: "STAG Integration", description: "Query and verify streamed data in database")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
                
                Button {
                    showingConfiguration = true
                } label: {
                    Text("Configure & Start")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Welcome")
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - AR Scanning View
struct ARScanningView: View {
    @EnvironmentObject private var streamManager: StreamManager
    @EnvironmentObject private var appState: AppState
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status header
                statusHeaderView
                
                // Metrics cards
                metricsCardsView
                
                // Control buttons
                controlButtonsView
                
                // Error display
                if let error = streamManager.lastError {
                    errorDisplayView(error)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("AR Scanning")
            .alert("AR Scanning", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var statusHeaderView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: streamManager.sessionState.icon)
                    .foregroundColor(Color(streamManager.sessionState.color))
                    .font(.title2)
                
                Text(streamManager.sessionState.displayText)
                    .font(.headline)
                
                Spacer()
                
                if let sessionID = streamManager.metrics.sessionID {
                    Text("Session: \(String(sessionID.prefix(8)))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if streamManager.connectionStatus.isConnected {
                HStack {
                    Image(systemName: "wifi")
                        .foregroundColor(.green)
                    Text("Connected to Relay")
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var metricsCardsView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            MetricCard(
                title: "FPS",
                value: String(format: "%.1f", streamManager.metrics.fps),
                subtitle: "Target: 30+",
                icon: "speedometer",
                color: fpsColor
            )
            
            MetricCard(
                title: "Packets",
                value: "\(streamManager.metrics.packetsSent)",
                subtitle: "Total sent",
                icon: "paperplane.fill",
                color: .blue
            )
            
            MetricCard(
                title: "Compression",
                value: String(format: "%.1f%%", streamManager.metrics.compressionRatio * 100),
                subtitle: "Size reduction",
                icon: "archivebox.fill",
                color: compressionColor
            )
            
            MetricCard(
                title: "Uptime",
                value: formatDuration(streamManager.metrics.uptime),
                subtitle: "Session duration",
                icon: "clock.fill",
                color: .purple
            )
        }
    }
    
    private var controlButtonsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Start/Stop button
                Button(action: toggleStreaming) {
                    HStack {
                        Image(systemName: isStreamingActive ? "stop.circle.fill" : "play.circle.fill")
                        Text(isStreamingActive ? "Stop" : "Start")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(isStreamingActive ? Color.red : Color.green)
                    .cornerRadius(12)
                }
                .disabled(!streamManager.isARKitSupported || appState.configuration.apiKey.isEmpty)
                
                // Pause/Resume button
                if isStreamingActive {
                    Button(action: togglePause) {
                        HStack {
                            Image(systemName: isPaused ? "play.circle" : "pause.circle")
                            Text(isPaused ? "Resume" : "Pause")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.orange)
                        .cornerRadius(12)
                    }
                }
            }
            
            if isStreamingActive {
                Button(action: {
                    streamManager.manualMeshCapture()
                }) {
                    HStack {
                        Image(systemName: "cube.transparent")
                        Text("Capture Mesh")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                }
            }
        }
    }
    
    private func errorDisplayView(_ error: Error) -> some View {
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
    }
    
    private var isStreamingActive: Bool {
        switch streamManager.sessionState {
        case .streaming, .paused, .connecting:
            return true
        default:
            return false
        }
    }
    
    private var isPaused: Bool {
        if case .paused = streamManager.sessionState {
            return true
        }
        return false
    }
    
    private var fpsColor: Color {
        let fps = streamManager.metrics.fps
        if fps >= 25 { return .green }
        if fps >= 15 { return .orange }
        return .red
    }
    
    private var compressionColor: Color {
        let ratio = streamManager.metrics.compressionRatio
        if ratio >= 0.8 { return .green }
        if ratio >= 0.6 { return .orange }
        return .red
    }
    
    private func toggleStreaming() {
        if isStreamingActive {
            streamManager.stopStreaming()
        } else {
            if appState.configuration.apiKey == "demo-api-key" {
                alertMessage = "Please configure your API key in settings before starting."
                showingAlert = true
                return
            }
            streamManager.startStreaming()
        }
    }
    
    private func togglePause() {
        if isPaused {
            streamManager.resumeStreaming()
        } else {
            streamManager.pauseStreaming()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// Placeholder views for other tabs - these would be fully implemented
struct MetricsDashboardView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                Text("Metrics Dashboard")
                    .font(.title)
                Text("Real-time performance charts and analytics")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Metrics")
        }
    }
}

struct LogViewerView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                Text("Log Viewer")
                    .font(.title)
                Text("Timestamped events with filtering and export")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Logs")
        }
    }
}

struct STAGQueryView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "externaldrive.connected.to.line.below")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                Text("STAG Verification")
                    .font(.title)
                Text("Query and verify streamed data in database")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("STAG")
        }
    }
}

struct ConfigurationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var localConfig: DemoConfiguration
    
    init() {
        _localConfig = State(initialValue: AppState.shared.configuration)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Connection") {
                    TextField("Relay URL", text: $localConfig.relayURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("API Key", text: $localConfig.apiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("STAG Query URL", text: $localConfig.stagQueryURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section("Compression") {
                    Picker("Level", selection: $localConfig.compressionLevel) {
                        ForEach(CompressionLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    
                    Text(localConfig.compressionLevel.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Advanced") {
                    Toggle("Auto Reconnect", isOn: $localConfig.autoReconnect)
                    Toggle("Verbose Logging", isOn: $localConfig.verboseLogging)
                }
            }
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        appState.configuration = localConfig
                        appState.saveConfiguration()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            localConfig = appState.configuration
        }
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        ContentView()
            .environmentObject(AppState.shared)
    } else {
        Text("iOS 16.0+ required")
    }
}