import SwiftUI

@main
struct StreamKitDemoApp: App {
    var body: some Scene {
        WindowGroup {
            if #available(iOS 16.0, visionOS 1.0, *) {
                ContentView()
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