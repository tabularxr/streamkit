import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var streamManager = StreamManager()
    @State private var selectedTab = 0
    @State private var showingConfiguration = false
    
    var body: some View {
        Group {
            if appState.isFirstLaunch || appState.configuration.apiKey.isEmpty {
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
                    
                    Text("StreamKit Test App")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("End-to-end testing for StreamKit SDK")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    FeatureRow(icon: "camera.fill", title: "AR Scanning", description: "Live ARKit data capture with mesh overlays")
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Real-time Metrics", description: "FPS, compression ratios, bandwidth usage")
                    FeatureRow(icon: "list.bullet.rectangle", title: "Live Logging", description: "Timestamped events with filtering")
                    FeatureRow(icon: "externaldrive.connected.to.line.below", title: "STAG Integration", description: "Query and verify streamed data")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
                
                Button {
                    showingConfiguration = true
                } label: {
                    Text("Get Started")
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

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
}