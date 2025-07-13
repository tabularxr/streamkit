import SwiftUI

struct LogViewerView: View {
    @EnvironmentObject private var streamManager: StreamManager
    @State private var selectedFilter: LogEntry.LogType? = nil
    @State private var searchText = ""
    @State private var showingExportSheet = false
    @State private var autoScroll = true
    
    private var filteredLogs: [LogEntry] {
        var logs = streamManager.logs
        
        // Apply type filter
        if let filter = selectedFilter {
            logs = logs.filter { $0.type == filter }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            logs = logs.filter { entry in
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                (entry.details?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return logs.reversed() // Show newest first
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter and search controls
                controlsSection
                
                // Log list
                logListSection
            }
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        autoScroll.toggle()
                    } label: {
                        Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                    }
                    
                    Button {
                        showingExportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(streamManager.logs.isEmpty)
                    
                    Button {
                        streamManager.clearLogs()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(streamManager.logs.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            LogExportView(logs: streamManager.logs)
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedFilter == nil,
                        count: streamManager.logs.count
                    ) {
                        selectedFilter = nil
                    }
                    
                    ForEach(LogEntry.LogType.allCases, id: \.self) { type in
                        let count = streamManager.logs.filter { $0.type == type }.count
                        
                        if count > 0 {
                            FilterChip(
                                title: type.rawValue,
                                isSelected: selectedFilter == type,
                                count: count,
                                color: Color(type.color)
                            ) {
                                selectedFilter = selectedFilter == type ? nil : type
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Log stats
            HStack {
                Text("Total: \(streamManager.logs.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !filteredLogs.isEmpty {
                    Text("Filtered: \(filteredLogs.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
    
    private var logListSection: some View {
        Group {
            if filteredLogs.isEmpty {
                emptyStateView
            } else {
                logList
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No logs found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if !searchText.isEmpty || selectedFilter != nil {
                Text("Try adjusting your filters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Clear Filters") {
                    searchText = ""
                    selectedFilter = nil
                }
                .buttonStyle(.bordered)
            } else {
                Text("Start streaming to see logs appear here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var logList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredLogs) { entry in
                    LogEntryRow(entry: entry)
                        .id(entry.id)
                }
            }
            .listStyle(.plain)
            .onChange(of: streamManager.logs.count) {
                if autoScroll && !filteredLogs.isEmpty {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(filteredLogs.first?.id, anchor: .top)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let color: Color
    let action: () -> Void
    
    init(title: String, isSelected: Bool, count: Int, color: Color = .blue, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.count = count
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.3))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color : .gray.opacity(0.3))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct LogEntryRow: View {
    let entry: LogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Type indicator
                VStack {
                    Image(systemName: entry.type.icon)
                        .foregroundColor(Color(entry.type.color))
                        .font(.caption)
                        .frame(width: 20, height: 20)
                        .background(Color(entry.type.color).opacity(0.1))
                        .cornerRadius(10)
                    
                    Spacer()
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Header
                    HStack {
                        Text(entry.type.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(entry.type.color).opacity(0.2))
                            .foregroundColor(Color(entry.type.color))
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Text(formatTimestamp(entry.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Message
                    Text(entry.message)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Details (expandable)
                    if let details = entry.details {
                        VStack(alignment: .leading, spacing: 4) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isExpanded.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("Details")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    
                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            if isExpanded {
                                Text(details)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 8)
                                    .padding(.vertical, 4)
                                    .background(.gray.opacity(0.1))
                                    .cornerRadius(4)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if entry.details != nil {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Log Export View
struct LogExportView: View {
    let logs: [LogEntry]
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat: ExportFormat = .text
    @State private var includeDetails = true
    @State private var selectedTypes: Set<LogEntry.LogType> = Set(LogEntry.LogType.allCases)
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Log Types") {
                    ForEach(LogEntry.LogType.allCases, id: \.self) { type in
                        let count = logs.filter { $0.type == type }.count
                        
                        HStack {
                            Button {
                                if selectedTypes.contains(type) {
                                    selectedTypes.remove(type)
                                } else {
                                    selectedTypes.insert(type)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedTypes.contains(type) ? "checkmark.square" : "square")
                                        .foregroundColor(.blue)
                                    
                                    Image(systemName: type.icon)
                                        .foregroundColor(Color(type.color))
                                    
                                    Text(type.rawValue)
                                    
                                    Spacer()
                                    
                                    Text("\(count)")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Section("Options") {
                    Toggle("Include Details", isOn: $includeDetails)
                }
                
                Section {
                    Button("Export Logs") {
                        exportLogs()
                    }
                    .disabled(selectedTypes.isEmpty)
                }
            }
            .navigationTitle("Export Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportLogs() {
        let filteredLogs = logs.filter { selectedTypes.contains($0.type) }
        let exportContent = generateExportContent(logs: filteredLogs)
        
        // Share the content
        let activityViewController = UIActivityViewController(
            activityItems: [exportContent],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
        
        dismiss()
    }
    
    private func generateExportContent(logs: [LogEntry]) -> String {
        switch exportFormat {
        case .text:
            return logs.map { entry in
                var content = "[\(formatTimestamp(entry.timestamp))] \(entry.type.rawValue): \(entry.message)"
                if includeDetails, let details = entry.details {
                    content += "\nDetails: \(details)"
                }
                return content
            }.joined(separator: "\n\n")
            
        case .csv:
            var csv = "Timestamp,Type,Message"
            if includeDetails {
                csv += ",Details"
            }
            csv += "\n"
            
            for entry in logs {
                let timestamp = formatTimestamp(entry.timestamp)
                let message = entry.message.replacingOccurrences(of: "\"", with: "\"\"")
                var line = "\"\(timestamp)\",\"\(entry.type.rawValue)\",\"\(message)\""
                
                if includeDetails {
                    let details = entry.details?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
                    line += ",\"\(details)\""
                }
                
                csv += line + "\n"
            }
            
            return csv
            
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let exportData = logs.map { entry in
                var data: [String: Any] = [
                    "timestamp": formatTimestamp(entry.timestamp),
                    "type": entry.type.rawValue,
                    "message": entry.message
                ]
                
                if includeDetails, let details = entry.details {
                    data["details"] = details
                }
                
                return data
            }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
            
            return "Error generating JSON"
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

enum ExportFormat: String, CaseIterable {
    case text = "Text"
    case csv = "CSV"
    case json = "JSON"
}

#Preview {
    LogViewerView()
        .environmentObject(StreamManager())
}