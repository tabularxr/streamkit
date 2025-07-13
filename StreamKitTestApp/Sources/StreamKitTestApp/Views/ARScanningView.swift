import SwiftUI
import ARKit
import RealityKit

struct ARScanningView: View {
    @EnvironmentObject private var streamManager: StreamManager
    @EnvironmentObject private var appState: AppState
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // AR View
                ARViewContainer()
                    .edgesIgnoringSafeArea(.all)
                
                // Overlay UI
                VStack {
                    // Top status bar
                    topStatusBar
                    
                    Spacer()
                    
                    // Bottom controls
                    bottomControls
                }
            }
            .navigationTitle("AR Scanning")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                streamManager.configure(with: appState.configuration)
            }
            .alert("AR Scanning", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private var topStatusBar: some View {
        HStack {
            // Session state indicator
            HStack(spacing: 8) {
                Image(systemName: streamManager.sessionState.icon)
                    .foregroundColor(Color(streamManager.sessionState.color))
                
                Text(streamManager.sessionState.displayText)
                    .font(.headline)
            }
            
            Spacer()
            
            // Quick metrics
            VStack(alignment: .trailing, spacing: 4) {
                Text("FPS: \(String(format: "%.1f", streamManager.metrics.fps))")
                    .font(.caption)
                Text("Packets: \(streamManager.metrics.packetsSent)")
                    .font(.caption)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Buffer status
            HStack {
                Image(systemName: "tray.fill")
                    .foregroundColor(.blue)
                Text(streamManager.meshBufferStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            
            // Main control buttons
            HStack(spacing: 20) {
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
            
            // Manual mesh capture button
            if isStreamingActive {
                Button(action: manualMeshCapture) {
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
            
            // Configuration warning
            if appState.configuration.apiKey.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Configure API key to start streaming")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.bottom, 20)
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
    
    private func toggleStreaming() {
        if isStreamingActive {
            streamManager.stopStreaming()
        } else {
            if appState.configuration.apiKey.isEmpty {
                alertMessage = "Please configure your API key in settings before starting."
                showingAlert = true
                return
            }
            
            if !streamManager.isARKitSupported {
                alertMessage = "ARKit is not supported on this device."
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
    
    private func manualMeshCapture() {
        streamManager.manualMeshCapture()
    }
}

// MARK: - ARView Container
struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .meshWithClassification
        configuration.environmentTexturing = .automatic
        
        arView.session.run(configuration)
        
        // Set up scene
        setupScene(arView)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Updates handled by ARKit delegate
    }
    
    private func setupScene(_ arView: ARView) {
        // Add lighting
        let anchor = AnchorEntity(.camera)
        arView.scene.addAnchor(anchor)
        
        // Enable mesh visualization
        arView.debugOptions.insert(.showSceneUnderstanding)
        
        // Set up mesh material
        setupMeshVisualization(arView)
    }
    
    private func setupMeshVisualization(_ arView: ARView) {
        // Create a wireframe material for mesh visualization
        var material = UnlitMaterial()
        material.color = .init(tint: .blue.withAlphaComponent(0.3))
        
        // Listen for mesh updates
        arView.scene.subscribe(to: SceneEvents.Update.self) { _ in
            // Update mesh visualization
            updateMeshVisualization(arView, material: material)
        }.store(in: &arView.scene.subscriptions)
    }
    
    private func updateMeshVisualization(_ arView: ARView, material: UnlitMaterial) {
        // Get current frame
        guard let frame = arView.session.currentFrame else { return }
        
        // Process mesh anchors
        for anchor in frame.anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                // Create or update mesh entity
                updateMeshEntity(for: meshAnchor, in: arView, material: material)
            }
        }
    }
    
    private func updateMeshEntity(for meshAnchor: ARMeshAnchor, in arView: ARView, material: UnlitMaterial) {
        let meshResource = try? MeshResource.generate(from: meshAnchor)
        
        if let meshResource = meshResource {
            let meshEntity = ModelEntity(mesh: meshResource, materials: [material])
            
            // Remove existing mesh entities for this anchor
            arView.scene.anchors.removeAll { anchor in
                anchor.name == meshAnchor.identifier.uuidString
            }
            
            // Add new mesh entity
            let anchorEntity = AnchorEntity(anchor: meshAnchor)
            anchorEntity.name = meshAnchor.identifier.uuidString
            anchorEntity.addChild(meshEntity)
            arView.scene.addAnchor(anchorEntity)
        }
    }
}

#Preview {
    ARScanningView()
        .environmentObject(StreamManager())
        .environmentObject(AppState.shared)
}