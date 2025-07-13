import SwiftUI
import Charts

struct MetricsDashboardView: View {
    @EnvironmentObject private var streamManager: StreamManager
    @State private var fpsHistory: [FPSDataPoint] = []
    @State private var bandwidthHistory: [BandwidthDataPoint] = []
    @State private var selectedMetric: MetricType = .fps
    @State private var refreshTimer: Timer?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Real-time metrics cards
                    metricsCardsSection
                    
                    // Performance charts
                    performanceChartsSection
                    
                    // Session information
                    sessionInformationSection
                    
                    // Connection status
                    connectionStatusSection
                }
                .padding()
            }
            .navigationTitle("Metrics")
            .onAppear {
                startMetricsTracking()
            }
            .onDisappear {
                stopMetricsTracking()
            }
        }
    }
    
    private var metricsCardsSection: some View {
        VStack(spacing: 16) {
            Text("Real-time Metrics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetricCard(
                    title: "FPS",
                    value: String(format: "%.1f", streamManager.metrics.fps),
                    subtitle: "Target: 30+",
                    icon: "speedometer",
                    color: fpsColor,
                    trend: fpsTrend
                )
                
                MetricCard(
                    title: "Packets Sent",
                    value: "\(streamManager.metrics.packetsSent)",
                    subtitle: "Total count",
                    icon: "paperplane.fill",
                    color: .blue
                )
                
                MetricCard(
                    title: "Compression",
                    value: String(format: "%.1f%%", streamManager.metrics.compressionRatio * 100),
                    subtitle: "Target: 80%+",
                    icon: "archivebox.fill",
                    color: compressionColor,
                    trend: compressionTrend
                )
                
                MetricCard(
                    title: "Bandwidth",
                    value: String(format: "%.1f KB/s", streamManager.metrics.bandwidth),
                    subtitle: "Upload rate",
                    icon: "wifi",
                    color: .green
                )
            }
        }
    }
    
    private var performanceChartsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Performance Trends")
                    .font(.headline)
                
                Spacer()
                
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(MetricType.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            Group {
                switch selectedMetric {
                case .fps:
                    fpsChart
                case .bandwidth:
                    bandwidthChart
                }
            }
            .frame(height: 200)
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
    
    private var fpsChart: some View {
        Chart(fpsHistory) { dataPoint in
            LineMark(
                x: .value("Time", dataPoint.timestamp),
                y: .value("FPS", dataPoint.fps)
            )
            .foregroundStyle(.blue)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel()
                AxisGridLine()
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel(format: .dateTime.hour().minute())
                AxisGridLine()
            }
        }
        .chartYScale(domain: 0...35)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var bandwidthChart: some View {
        Chart(bandwidthHistory) { dataPoint in
            AreaMark(
                x: .value("Time", dataPoint.timestamp),
                y: .value("Bandwidth", dataPoint.bandwidth)
            )
            .foregroundStyle(.green.opacity(0.3))
            
            LineMark(
                x: .value("Time", dataPoint.timestamp),
                y: .value("Bandwidth", dataPoint.bandwidth)
            )
            .foregroundStyle(.green)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel()
                AxisGridLine()
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel(format: .dateTime.hour().minute())
                AxisGridLine()
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var sessionInformationSection: some View {
        VStack(spacing: 16) {
            Text("Session Information")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                SessionInfoRow(
                    label: "Session ID",
                    value: streamManager.metrics.sessionID ?? "Not connected",
                    icon: "person.crop.circle.badge.checkmark"
                )
                
                SessionInfoRow(
                    label: "Uptime",
                    value: formatDuration(streamManager.metrics.uptime),
                    icon: "clock.fill"
                )
                
                SessionInfoRow(
                    label: "Error Count",
                    value: "\(streamManager.metrics.errorCount)",
                    icon: "exclamationmark.triangle.fill",
                    valueColor: streamManager.metrics.errorCount > 0 ? .red : .green
                )
                
                SessionInfoRow(
                    label: "Success Rate",
                    value: String(format: "%.1f%%", calculateSuccessRate()),
                    icon: "checkmark.circle.fill",
                    valueColor: successRateColor
                )
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
    
    private var connectionStatusSection: some View {
        VStack(spacing: 16) {
            Text("Connection Status")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: streamManager.connectionStatus.isConnected ? "wifi" : "wifi.slash")
                        .foregroundColor(streamManager.connectionStatus.isConnected ? .green : .red)
                    
                    Text(streamManager.connectionStatus.isConnected ? "Connected" : "Disconnected")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if streamManager.connectionStatus.isConnected {
                        Text("Online")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                    }
                }
                
                if let lastConnected = streamManager.connectionStatus.lastConnected {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.gray)
                        Text("Last connected: \(formatTimestamp(lastConnected))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                
                if streamManager.connectionStatus.reconnectAttempts > 0 {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.orange)
                        Text("Reconnect attempts: \(streamManager.connectionStatus.reconnectAttempts)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                
                if let latency = streamManager.connectionStatus.latency {
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundColor(.blue)
                        Text("Latency: \(String(format: "%.0f", latency * 1000))ms")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Computed Properties
    private var fpsColor: Color {
        let fps = streamManager.metrics.fps
        if fps >= 25 { return .green }
        if fps >= 15 { return .orange }
        return .red
    }
    
    private var fpsTrend: TrendDirection? {
        guard fpsHistory.count >= 2 else { return nil }
        let recent = fpsHistory.suffix(5).map { $0.fps }
        let avg = recent.reduce(0, +) / Double(recent.count)
        let previous = fpsHistory.dropLast(5).suffix(5).map { $0.fps }
        guard !previous.isEmpty else { return nil }
        let prevAvg = previous.reduce(0, +) / Double(previous.count)
        
        if avg > prevAvg * 1.05 { return .up }
        if avg < prevAvg * 0.95 { return .down }
        return .stable
    }
    
    private var compressionColor: Color {
        let ratio = streamManager.metrics.compressionRatio
        if ratio >= 0.8 { return .green }
        if ratio >= 0.6 { return .orange }
        return .red
    }
    
    private var compressionTrend: TrendDirection? {
        // Similar logic to FPS trend but for compression ratio
        return .stable // Simplified for now
    }
    
    private var successRateColor: Color {
        let rate = calculateSuccessRate()
        if rate >= 95 { return .green }
        if rate >= 80 { return .orange }
        return .red
    }
    
    // MARK: - Helper Methods
    private func startMetricsTracking() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateMetricsHistory()
        }
    }
    
    private func stopMetricsTracking() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func updateMetricsHistory() {
        let now = Date()
        
        // Update FPS history
        fpsHistory.append(FPSDataPoint(
            timestamp: now,
            fps: streamManager.metrics.fps
        ))
        
        // Update bandwidth history
        bandwidthHistory.append(BandwidthDataPoint(
            timestamp: now,
            bandwidth: streamManager.metrics.bandwidth
        ))
        
        // Keep only last 60 data points (1 minute at 1Hz)
        if fpsHistory.count > 60 {
            fpsHistory.removeFirst(fpsHistory.count - 60)
        }
        
        if bandwidthHistory.count > 60 {
            bandwidthHistory.removeFirst(bandwidthHistory.count - 60)
        }
    }
    
    private func calculateSuccessRate() -> Double {
        let total = streamManager.metrics.packetsSent
        let errors = streamManager.metrics.errorCount
        guard total > 0 else { return 100.0 }
        return Double(total - errors) / Double(total) * 100.0
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views
struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let trend: TrendDirection?
    
    init(title: String, value: String, subtitle: String, icon: String, color: Color, trend: TrendDirection? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.trend = trend
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
                
                if let trend = trend {
                    Image(systemName: trend.icon)
                        .foregroundColor(trend.color)
                        .font(.caption)
                }
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

struct SessionInfoRow: View {
    let label: String
    let value: String
    let icon: String
    let valueColor: Color
    
    init(label: String, value: String, icon: String, valueColor: Color = .primary) {
        self.label = label
        self.value = value
        self.icon = icon
        self.valueColor = valueColor
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Data Models
struct FPSDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let fps: Double
}

struct BandwidthDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let bandwidth: Double
}

enum MetricType: String, CaseIterable {
    case fps = "FPS"
    case bandwidth = "Bandwidth"
}

enum TrendDirection {
    case up, down, stable
    
    var icon: String {
        switch self {
        case .up: return "arrow.up.circle.fill"
        case .down: return "arrow.down.circle.fill"
        case .stable: return "minus.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .stable: return .gray
        }
    }
}

#Preview {
    MetricsDashboardView()
        .environmentObject(StreamManager())
}