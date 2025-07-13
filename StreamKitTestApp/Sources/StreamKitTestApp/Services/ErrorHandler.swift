import Foundation
import SwiftUI

// MARK: - Error Handling Service
@MainActor
class ErrorHandler: ObservableObject {
    @Published var currentError: AppError?
    @Published var showingAlert = false
    @Published var showingRecoveryOptions = false
    
    static let shared = ErrorHandler()
    
    private init() {}
    
    func handle(_ error: Error, context: String = "") {
        let appError = mapToAppError(error, context: context)
        currentError = appError
        showingAlert = true
        
        // Log the error
        logError(appError)
        
        // Auto-dismiss non-critical errors after 5 seconds
        if !appError.isCritical {
            Task {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                if currentError?.id == appError.id {
                    clearError()
                }
            }
        }
    }
    
    func clearError() {
        currentError = nil
        showingAlert = false
        showingRecoveryOptions = false
    }
    
    func showRecoveryOptions() {
        showingRecoveryOptions = true
    }
    
    private func mapToAppError(_ error: Error, context: String) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Map common system errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return AppError.networkError(
                    "No internet connection. Check your network settings and try again.",
                    recovery: .reconnect,
                    isCritical: false
                )
            case .timedOut:
                return AppError.networkError(
                    "Connection timed out. The server may be overloaded.",
                    recovery: .retry,
                    isCritical: false
                )
            case .cannotFindHost:
                return AppError.configurationError(
                    "Cannot reach server. Check your Relay URL in settings.",
                    recovery: .configure,
                    isCritical: true
                )
            default:
                return AppError.networkError(
                    "Network error: \(urlError.localizedDescription)",
                    recovery: .retry,
                    isCritical: false
                )
            }
        }
        
        // Default mapping
        return AppError.unknown(
            error.localizedDescription,
            recovery: .restart,
            isCritical: false
        )
    }
    
    private func logError(_ error: AppError) {
        print("🚨 Error: \(error.title)")
        print("   Message: \(error.message)")
        print("   Recovery: \(error.recovery)")
        print("   Critical: \(error.isCritical)")
        print("   Context: \(error.context ?? "N/A")")
    }
}

// MARK: - App Error Types
struct AppError: LocalizedError, Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let recovery: RecoveryAction
    let isCritical: Bool
    let context: String?
    
    var errorDescription: String? {
        return message
    }
    
    // MARK: - Factory Methods
    static func arkitError(_ message: String, recovery: RecoveryAction = .checkPermissions, context: String? = nil) -> AppError {
        AppError(
            title: "ARKit Error",
            message: message,
            recovery: recovery,
            isCritical: true,
            context: context
        )
    }
    
    static func networkError(_ message: String, recovery: RecoveryAction = .retry, context: String? = nil) -> AppError {
        AppError(
            title: "Network Error",
            message: message,
            recovery: recovery,
            isCritical: false,
            context: context
        )
    }
    
    static func configurationError(_ message: String, recovery: RecoveryAction = .configure, context: String? = nil) -> AppError {
        AppError(
            title: "Configuration Error",
            message: message,
            recovery: recovery,
            isCritical: true,
            context: context
        )
    }
    
    static func streamingError(_ message: String, recovery: RecoveryAction = .restart, context: String? = nil) -> AppError {
        AppError(
            title: "Streaming Error",
            message: message,
            recovery: recovery,
            isCritical: false,
            context: context
        )
    }
    
    static func compressionError(_ message: String, recovery: RecoveryAction = .reducequality, context: String? = nil) -> AppError {
        AppError(
            title: "Compression Error",
            message: message,
            recovery: recovery,
            isCritical: false,
            context: context
        )
    }
    
    static func authenticationError(_ message: String, recovery: RecoveryAction = .configure, context: String? = nil) -> AppError {
        AppError(
            title: "Authentication Error",
            message: message,
            recovery: recovery,
            isCritical: true,
            context: context
        )
    }
    
    static func unknown(_ message: String, recovery: RecoveryAction = .restart, context: String? = nil) -> AppError {
        AppError(
            title: "Unknown Error",
            message: message,
            recovery: recovery,
            isCritical: false,
            context: context
        )
    }
}

// MARK: - Recovery Actions
enum RecoveryAction: String, CaseIterable {
    case retry = "Retry"
    case restart = "Restart Streaming"
    case reconnect = "Reconnect"
    case configure = "Check Settings"
    case checkPermissions = "Check Permissions"
    case reducequality = "Reduce Quality"
    case contactSupport = "Contact Support"
    case ignore = "Ignore"
    
    var icon: String {
        switch self {
        case .retry: return "arrow.clockwise"
        case .restart: return "play.circle"
        case .reconnect: return "wifi"
        case .configure: return "gear"
        case .checkPermissions: return "lock.shield"
        case .reducequality: return "slider.horizontal.below.rectangle"
        case .contactSupport: return "questionmark.circle"
        case .ignore: return "xmark.circle"
        }
    }
    
    var description: String {
        switch self {
        case .retry: return "Try the operation again"
        case .restart: return "Stop and restart streaming"
        case .reconnect: return "Check network and reconnect"
        case .configure: return "Review app configuration"
        case .checkPermissions: return "Check camera and ARKit permissions"
        case .reducequality: return "Lower compression or quality settings"
        case .contactSupport: return "Get help from support team"
        case .ignore: return "Continue despite the error"
        }
    }
}

// MARK: - Error Alert View
struct ErrorAlertView: View {
    @ObservedObject var errorHandler: ErrorHandler
    let onRecoveryAction: (RecoveryAction) -> Void
    
    var body: some View {
        Group {
            if let error = errorHandler.currentError {
                EmptyView()
                    .alert(error.title, isPresented: $errorHandler.showingAlert) {
                        // Primary recovery action
                        Button(error.recovery.rawValue) {
                            onRecoveryAction(error.recovery)
                            errorHandler.clearError()
                        }
                        
                        // Secondary actions for critical errors
                        if error.isCritical {
                            Button("More Options") {
                                errorHandler.showRecoveryOptions()
                            }
                        }
                        
                        // Dismiss button
                        Button("Dismiss", role: .cancel) {
                            errorHandler.clearError()
                        }
                    } message: {
                        Text(error.message)
                    }
                    .sheet(isPresented: $errorHandler.showingRecoveryOptions) {
                        if let error = errorHandler.currentError {
                            RecoveryOptionsView(
                                error: error,
                                onAction: onRecoveryAction
                            )
                        }
                    }
            }
        }
    }
}

// MARK: - Recovery Options View
struct RecoveryOptionsView: View {
    let error: AppError
    let onAction: (RecoveryAction) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Error details
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text(error.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(error.message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Recovery actions
                VStack(spacing: 16) {
                    Text("Recovery Options")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ForEach(getRelevantActions(), id: \.self) { action in
                        RecoveryActionRow(action: action) {
                            onAction(action)
                            dismiss()
                        }
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Error Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getRelevantActions() -> [RecoveryAction] {
        switch error.title {
        case "ARKit Error":
            return [.checkPermissions, .restart, .configure, .contactSupport]
        case "Network Error":
            return [.reconnect, .retry, .configure, .ignore]
        case "Configuration Error":
            return [.configure, .contactSupport, .restart]
        case "Streaming Error":
            return [.restart, .retry, .reducequality, .configure]
        case "Compression Error":
            return [.reducequality, .restart, .ignore, .contactSupport]
        case "Authentication Error":
            return [.configure, .contactSupport, .restart]
        default:
            return [.restart, .configure, .contactSupport]
        }
    }
}

struct RecoveryActionRow: View {
    let action: RecoveryAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: action.icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(action.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Background App State Handler
@MainActor
class AppStateHandler: ObservableObject {
    @Published var isInBackground = false
    @Published var shouldResumeOnForeground = false
    
    private var streamManager: StreamManager?
    
    func configure(streamManager: StreamManager) {
        self.streamManager = streamManager
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDidEnterBackground()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillEnterForeground()
        }
    }
    
    private func handleDidEnterBackground() {
        isInBackground = true
        
        // Pause streaming if active
        if case .streaming = streamManager?.sessionState {
            streamManager?.pauseStreaming()
            shouldResumeOnForeground = true
        }
    }
    
    private func handleWillEnterForeground() {
        isInBackground = false
        
        // Resume streaming if it was paused
        if shouldResumeOnForeground {
            Task {
                // Wait a moment for the app to fully restore
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                streamManager?.resumeStreaming()
                shouldResumeOnForeground = false
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}