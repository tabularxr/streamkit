import SwiftUI
import SceneKit

struct STAGQueryView: View {
    @EnvironmentObject private var streamManager: StreamManager
    @EnvironmentObject private var appState: AppState
    @StateObject private var stagService = STAGQueryService()
    
    @State private var showingQueryResults = false
    @State private var selectedAnchor: PoseAnchor?
    @State private var showingMeshViewer = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Query section
                querySection
                
                // Results section
                if stagService.isLoading {
                    loadingSection
                } else if let result = stagService.lastResult {
                    resultsSection(result)
                } else {
                    emptyStateSection
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("STAG Verification")
            .refreshable {
                await performQuery()
            }
        }
        .sheet(isPresented: $showingMeshViewer) {
            if let anchor = selectedAnchor {
                MeshViewerSheet(anchor: anchor)
            }
        }
    }
    
    private var querySection: some View {
        VStack(spacing: 16) {
            Text("Query Streamed Data")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                // Session info
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Session")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(streamManager.metrics.sessionID ?? "No active session")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
                
                // STAG endpoint
                HStack {
                    Image(systemName: "externaldrive.connected.to.line.below")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("STAG Endpoint")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(appState.configuration.stagQueryURL)
                            .font(.caption)
                            .fontFamily(.monospaced)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                // Query button
                Button {
                    Task {
                        await performQuery()
                    }
                } label: {
                    HStack {
                        if stagService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        
                        Text(stagService.isLoading ? "Querying STAG..." : "Verify in STAG")
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(stagService.isLoading || streamManager.metrics.sessionID == nil)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Querying STAG database...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("This may take a few seconds")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func resultsSection(_ result: QueryResult) -> some View {
        VStack(spacing: 16) {
            // Summary cards
            HStack(spacing: 16) {
                ResultCard(
                    title: "Anchors",
                    value: "\(result.anchors.count)",
                    subtitle: "Pose anchors found",
                    icon: "location.fill",
                    color: .blue
                )
                
                ResultCard(
                    title: "Meshes",
                    value: "\(result.meshCount)",
                    subtitle: "Mesh objects found",
                    icon: "cube.fill",
                    color: .green
                )
            }
            
            HStack(spacing: 16) {
                ResultCard(
                    title: "Data Size",
                    value: formatBytes(result.totalDataSize),
                    subtitle: "Total decompressed",
                    icon: "internaldrive.fill",
                    color: .orange
                )
                
                ResultCard(
                    title: "Query Time",
                    value: String(format: "%.2fs", result.queryTime),
                    subtitle: "Response time",
                    icon: "speedometer",
                    color: .purple
                )
            }
            
            // Anchors list
            if !result.anchors.isEmpty {
                anchorsListSection(result.anchors)
            }
            
            // Error state
            if result.anchors.isEmpty && result.meshCount == 0 {
                noDataFoundSection
            }
        }
    }
    
    private func anchorsListSection(_ anchors: [PoseAnchor]) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Pose Anchors")
                    .font(.headline)
                
                Spacer()
                
                Text("\(anchors.count) found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(anchors) { anchor in
                        AnchorRow(anchor: anchor) {
                            selectedAnchor = anchor
                            showingMeshViewer = true
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var noDataFoundSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No data found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("The session may not have streamed any data yet, or STAG might be empty.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("STAG Verification")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Query the STAG database to verify that your streamed data was received and stored correctly.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if streamManager.metrics.sessionID == nil {
                Text("Start a streaming session first, then query STAG to verify the data.")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func performQuery() async {
        guard let sessionID = streamManager.metrics.sessionID else { return }
        
        await stagService.querySession(
            sessionID: sessionID,
            stagURL: appState.configuration.stagQueryURL
        )
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Supporting Views
struct ResultCard: View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct AnchorRow: View {
    let anchor: PoseAnchor
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.fill")
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Frame \(anchor.frameNumber)")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(formatTimestamp(Date(timeIntervalSince1970: anchor.timestamp)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Position: \(anchor.formattedPosition)")
                    .font(.caption)
                    .fontFamily(.monospaced)
                    .foregroundColor(.secondary)
            }
            
            Button {
                onTap()
            } label: {
                Image(systemName: "eye.fill")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.white.opacity(0.05))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Mesh Viewer Sheet
struct MeshViewerSheet: View {
    let anchor: PoseAnchor
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Anchor details
                VStack(alignment: .leading, spacing: 12) {
                    Text("Anchor Details")
                        .font(.headline)
                    
                    DetailRow(label: "Frame Number", value: "\(anchor.frameNumber)")
                    DetailRow(label: "Timestamp", value: formatTimestamp(Date(timeIntervalSince1970: anchor.timestamp)))
                    DetailRow(label: "Position", value: anchor.formattedPosition)
                    DetailRow(label: "Rotation", value: formatQuaternion(anchor.rotation))
                    DetailRow(label: "Anchor ID", value: String(anchor.id.prefix(8)) + "...")
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                
                // 3D Scene View (placeholder)
                VStack {
                    Text("3D Scene Viewer")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .frame(height: 300)
                        .overlay {
                            VStack(spacing: 12) {
                                Image(systemName: "cube.transparent")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                
                                Text("3D mesh visualization would appear here")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Text("Requires SceneKit integration with decompressed mesh data")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Mesh Viewer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatQuaternion(_ quat: simd_quatf) -> String {
        return String(format: "(%.3f, %.3f, %.3f, %.3f)", quat.vector.x, quat.vector.y, quat.vector.z, quat.vector.w)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .fontFamily(.monospaced)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}

// MARK: - STAG Query Service
@MainActor
class STAGQueryService: ObservableObject {
    @Published var isLoading = false
    @Published var lastResult: QueryResult?
    @Published var lastError: String?
    
    func querySession(sessionID: String, stagURL: String) async {
        isLoading = true
        lastError = nil
        
        do {
            let result = try await performSTAGQuery(sessionID: sessionID, stagURL: stagURL)
            lastResult = result
        } catch {
            lastError = error.localizedDescription
            lastResult = QueryResult.empty
        }
        
        isLoading = false
    }
    
    private func performSTAGQuery(sessionID: String, stagURL: String) async throws -> QueryResult {
        guard let url = URL(string: stagURL) else {
            throw STAGQueryError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let queryBody = [
            "session_id": sessionID,
            "include_meshes": true,
            "decompress": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: queryBody)
        
        let startTime = Date()
        
        // Simulate network request for demo
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        let queryTime = Date().timeIntervalSince(startTime)
        
        // Mock response data for demo
        let mockAnchors = generateMockAnchors(count: Int.random(in: 5...20))
        let mockMeshCount = Int.random(in: 2...8)
        let mockDataSize = Int.random(in: 1024*1024...10*1024*1024) // 1-10 MB
        
        return QueryResult(
            anchors: mockAnchors,
            meshCount: mockMeshCount,
            decompressedSizes: [:],
            totalDataSize: mockDataSize,
            queryTime: queryTime
        )
    }
    
    private func generateMockAnchors(count: Int) -> [PoseAnchor] {
        let baseTime = Date().timeIntervalSince1970 - 300 // 5 minutes ago
        
        return (0..<count).map { index in
            PoseAnchor(
                id: UUID().uuidString,
                position: SIMD3<Float>(
                    Float.random(in: -2...2),
                    Float.random(in: 0...2),
                    Float.random(in: -2...2)
                ),
                rotation: simd_quatf(
                    angle: Float.random(in: 0...2*Float.pi),
                    axis: SIMD3<Float>(0, 1, 0)
                ),
                timestamp: baseTime + Double(index) * 0.1,
                frameNumber: index * 3 + 1
            )
        }
    }
}

enum STAGQueryError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid STAG URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from STAG"
        }
    }
}

#Preview {
    STAGQueryView()
        .environmentObject(StreamManager())
        .environmentObject(AppState.shared)
}