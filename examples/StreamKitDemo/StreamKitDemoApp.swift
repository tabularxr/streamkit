import SwiftUI

@main
struct StreamKitDemoApp: App {
    @StateObject private var appState = AppState.shared
    
    var body: some Scene {
        WindowGroup {
            if #available(iOS 16.0, visionOS 1.0, *) {
                ContentView()
                    .environmentObject(appState)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        appState.initialize()
                    }
            } else {
                VStack {
                    Text("StreamKit Demo")
                        .font(.largeTitle)
                        .padding()
                    
                    Text("Requires iOS 16.0 or later")
                        .font(.headline)
                        .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - App State Manager
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var configuration = DemoConfiguration.default
    @Published var isFirstLaunch = true
    
    private init() {}
    
    func initialize() {
        loadConfiguration()
        checkFirstLaunch()
    }
    
    private func loadConfiguration() {
        // Load configuration from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "DemoConfiguration"),
           let config = try? JSONDecoder().decode(DemoConfiguration.self, data: data) {
            configuration = config
        }
    }
    
    func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "DemoConfiguration")
        }
    }
    
    private func checkFirstLaunch() {
        isFirstLaunch = !UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        }
    }
}

// MARK: - Demo Configuration
struct DemoConfiguration: Codable {
    var relayURL: String
    var apiKey: String
    var compressionLevel: CompressionLevel
    var autoReconnect: Bool
    var verboseLogging: Bool
    var stagQueryURL: String
    
    static let `default` = DemoConfiguration(
        relayURL: "ws://localhost:8080/ws/streamkit",
        apiKey: "demo-api-key",
        compressionLevel: .medium,
        autoReconnect: true,
        verboseLogging: false,
        stagQueryURL: "http://localhost:8081/query"
    )
}

enum CompressionLevel: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var description: String {
        switch self {
        case .low: return "Faster compression, larger files"
        case .medium: return "Balanced performance and size"
        case .high: return "Best compression, slower processing"
        }
    }
}