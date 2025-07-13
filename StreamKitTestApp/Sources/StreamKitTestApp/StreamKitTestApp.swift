import SwiftUI

@main
struct StreamKitTestApp: App {
    @StateObject private var appState = AppState.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onAppear {
                    appState.initialize()
                }
        }
    }
}

// MARK: - App State Manager
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var configuration = AppConfiguration.default
    @Published var isFirstLaunch = true
    
    private init() {}
    
    func initialize() {
        loadConfiguration()
        checkFirstLaunch()
    }
    
    private func loadConfiguration() {
        // Load configuration from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "AppConfiguration"),
           let config = try? JSONDecoder().decode(AppConfiguration.self, data: data) {
            configuration = config
        }
    }
    
    func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "AppConfiguration")
        }
    }
    
    private func checkFirstLaunch() {
        isFirstLaunch = !UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        }
    }
}

extension AppConfiguration: Codable {}