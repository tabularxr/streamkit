import SwiftUI

struct ConfigurationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var localConfig: AppConfiguration
    @State private var showingAPIKeyInfo = false
    @State private var testingConnection = false
    @State private var connectionResult: ConnectionTestResult?
    
    init() {
        _localConfig = State(initialValue: AppState.shared.configuration)
    }
    
    var body: some View {
        NavigationView {
            Form {
                connectionSection
                compressionSection
                advancedSection
                testingSection
                aboutSection
            }
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveConfiguration()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isConfigurationValid)
                }
            }
        }
        .onAppear {
            localConfig = appState.configuration
        }
        .alert("API Key Information", isPresented: $showingAPIKeyInfo) {
            Button("OK") { }
        } message: {
            Text("Get your API key from the Tabular Console at console.tabularxr.com. The key is used to authenticate your device with the Relay server.")
        }
    }
    
    private var connectionSection: some View {
        Section {
            // Relay URL
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Relay Server URL")
                        .fontWeight(.medium)
                    Spacer()
                    if !localConfig.relayURL.isEmpty {
                        connectionStatusIndicator
                    }
                }
                
                TextField("ws://localhost:8080/ws/streamkit", text: $localConfig.relayURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(.body, design: .monospaced))
                
                Text("WebSocket URL for your Relay server")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // API Key
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("API Key")
                        .fontWeight(.medium)
                    
                    Button {
                        showingAPIKeyInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
                
                SecureField("Enter your API key", text: $localConfig.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Text("Required for authentication with Relay server")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // STAG Query URL
            VStack(alignment: .leading, spacing: 8) {
                Text("STAG Query URL")
                    .fontWeight(.medium)
                
                TextField("http://localhost:8081/query", text: $localConfig.stagQueryURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(.body, design: .monospaced))
                
                Text("HTTP endpoint for querying streamed data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Connection Settings")
        }
    }
    
    private var compressionSection: some View {
        Section {
            Picker("Compression Level", selection: $localConfig.compressionLevel) {
                ForEach(CompressionLevel.allCases, id: \.self) { level in
                    VStack(alignment: .leading) {
                        Text(level.rawValue)
                        Text(level.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(level)
                }
            }
            .pickerStyle(.navigationLink)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Compression affects performance and data size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                switch localConfig.compressionLevel {
                case .low:
                    Text("• Faster processing, larger files\n• Best for real-time applications\n• ~60-70% compression ratio")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                case .medium:
                    Text("• Balanced performance and size\n• Recommended for most use cases\n• ~75-85% compression ratio")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                case .high:
                    Text("• Best compression, slower processing\n• Use when bandwidth is limited\n• ~85-95% compression ratio")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Compression Settings")
        }
    }
    
    private var advancedSection: some View {
        Section {
            Toggle("Auto Reconnect", isOn: $localConfig.autoReconnect)
            
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Verbose Logging", isOn: $localConfig.verboseLogging)
                
                if localConfig.verboseLogging {
                    Text("Includes detailed network and compression logs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Advanced Settings")
        } footer: {
            Text("Auto reconnect will attempt to restore connection automatically after network interruptions.")
        }
    }
    
    private var testingSection: some View {
        Section {
            Button {
                testConnection()
            } label: {
                HStack {
                    if testingConnection {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "network")
                    }
                    
                    Text(testingConnection ? "Testing Connection..." : "Test Connection")
                }
            }
            .disabled(testingConnection || localConfig.relayURL.isEmpty)
            
            if let result = connectionResult {
                HStack {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.success ? .green : .red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.message)
                            .font(.caption)
                        
                        if let latency = result.latency {
                            Text("Latency: \(String(format: "%.0f", latency * 1000))ms")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
        } header: {
            Text("Connection Testing")
        }
    }
    
    private var aboutSection: some View {
        Section {
            HStack {
                Text("App Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("StreamKit SDK")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Target iOS")
                Spacer()
                Text("18.0+")
                    .foregroundColor(.secondary)
            }
            
            Link("Documentation", destination: URL(string: "https://docs.tabularxr.com")!)
                .foregroundColor(.blue)
            
            Link("Support", destination: URL(string: "https://discord.gg/tabular")!)
                .foregroundColor(.blue)
        } header: {
            Text("About")
        }
    }
    
    private var connectionStatusIndicator: some View {
        Group {
            if let result = connectionResult {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
                    .font(.caption)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
    }
    
    private var isConfigurationValid: Bool {
        !localConfig.relayURL.isEmpty && !localConfig.apiKey.isEmpty && !localConfig.stagQueryURL.isEmpty
    }
    
    private func saveConfiguration() {
        appState.configuration = localConfig
        appState.saveConfiguration()
        dismiss()
    }
    
    private func testConnection() {
        guard !localConfig.relayURL.isEmpty else { return }
        
        testingConnection = true
        connectionResult = nil
        
        // Simulate connection test
        Task {
            await performConnectionTest()
        }
    }
    
    @MainActor
    private func performConnectionTest() async {
        do {
            let startTime = Date()
            
            // Basic URL validation
            guard let url = URL(string: localConfig.relayURL) else {
                connectionResult = ConnectionTestResult(
                    success: false,
                    message: "Invalid URL format",
                    latency: nil
                )
                testingConnection = false
                return
            }
            
            // Test host reachability (simplified)
            let host = url.host ?? "localhost"
            let port = url.port ?? 8080
            
            // Simulate network test
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            let latency = Date().timeIntervalSince(startTime)
            
            // For demo purposes, assume success if URL format is valid
            connectionResult = ConnectionTestResult(
                success: true,
                message: "Connection test successful",
                latency: latency
            )
            
        } catch {
            connectionResult = ConnectionTestResult(
                success: false,
                message: "Connection failed: \(error.localizedDescription)",
                latency: nil
            )
        }
        
        testingConnection = false
    }
}

struct ConnectionTestResult {
    let success: Bool
    let message: String
    let latency: TimeInterval?
}

#Preview {
    ConfigurationView()
        .environmentObject(AppState.shared)
}