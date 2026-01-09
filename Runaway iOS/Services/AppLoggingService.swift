//
//  AppLoggingService.swift
//  Runaway iOS
//
//  Centralized logging service that sends logs to Supabase
//

import Foundation
import UIKit

/// Log levels for categorizing log messages
enum AppLogLevel: String, Codable {
    case debug = "debug"
    case info = "info"
    case warn = "warn"
    case error = "error"
}

/// Log entry structure matching Supabase table
struct AppLogEntry: Encodable {
    let source: String
    let function_name: String?
    let level: String
    let message: String
    let user_id: String?
    let athlete_id: Int?
    let session_id: String?
    let request_method: String?
    let request_path: String?
    let response_status: Int?
    let duration_ms: Int?
    let error_message: String?
    let error_stack: String?
    let device_info: LogDeviceInfo?
    let environment: String
}

struct LogDeviceInfo: Encodable {
    let model: String
    let os_version: String
    let app_version: String
    let build_number: String
}

/// Centralized logging service for the app
@MainActor
final class AppLoggingService {
    static let shared = AppLoggingService()

    private let sessionId: String
    private var logQueue: [AppLogEntry] = []
    private let batchSize = 10
    private let flushInterval: TimeInterval = 30 // seconds
    private var flushTimer: Timer?

    private init() {
        sessionId = UUID().uuidString

        // Start periodic flush
        startFlushTimer()

        // Flush on app background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(flushLogs),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    deinit {
        flushTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Logging Methods

    /// Log a debug message
    func debug(_ message: String, function: String? = nil) {
        log(level: .debug, message: message, functionName: function)
    }

    /// Log an info message
    func info(_ message: String, function: String? = nil) {
        log(level: .info, message: message, functionName: function)
    }

    /// Log a warning
    func warn(_ message: String, function: String? = nil) {
        log(level: .warn, message: message, functionName: function)
    }

    /// Log an error
    func error(_ message: String, error: Error? = nil, function: String? = nil) {
        log(
            level: .error,
            message: message,
            functionName: function,
            errorMessage: error?.localizedDescription,
            errorStack: (error as NSError?)?.userInfo.description
        )
    }

    /// Log an API request
    func logRequest(method: String, path: String, function: String? = nil) {
        log(
            level: .info,
            message: "API Request: \(method) \(path)",
            functionName: function,
            requestMethod: method,
            requestPath: path
        )
    }

    /// Log an API response
    func logResponse(method: String, path: String, status: Int, durationMs: Int? = nil, function: String? = nil) {
        let level: AppLogLevel = (200...299).contains(status) ? .info : .error
        log(
            level: level,
            message: "API Response: \(method) \(path) - \(status)",
            functionName: function,
            requestMethod: method,
            requestPath: path,
            responseStatus: status,
            durationMs: durationMs
        )
    }

    /// Log authentication event
    func logAuth(event: String) {
        log(
            level: .info,
            message: "Auth: \(event)",
            functionName: "Auth"
        )
    }

    // MARK: - Private Methods

    private func log(
        level: AppLogLevel,
        message: String,
        functionName: String? = nil,
        requestMethod: String? = nil,
        requestPath: String? = nil,
        responseStatus: Int? = nil,
        durationMs: Int? = nil,
        errorMessage: String? = nil,
        errorStack: String? = nil
    ) {
        // Also print to console in debug
        #if DEBUG
        let icon: String
        switch level {
        case .debug: icon = "🔍"
        case .info: icon = "ℹ️"
        case .warn: icon = "⚠️"
        case .error: icon = "❌"
        }
        print("\(icon) [\(functionName ?? "App")] \(message)")
        #endif

        let entry = AppLogEntry(
            source: "ios",
            function_name: functionName,
            level: level.rawValue,
            message: message,
            user_id: UserSession.shared.userId.map { String($0) },
            athlete_id: DataManager.shared.athlete?.id,
            session_id: sessionId,
            request_method: requestMethod,
            request_path: requestPath,
            response_status: responseStatus,
            duration_ms: durationMs,
            error_message: errorMessage,
            error_stack: errorStack,
            device_info: getDeviceInfo(),
            environment: getEnvironment()
        )

        logQueue.append(entry)

        // Flush if batch size reached or error level
        if logQueue.count >= batchSize || level == .error {
            Task { await sendLogs() }
        }
    }

    private func getDeviceInfo() -> LogDeviceInfo {
        LogDeviceInfo(
            model: UIDevice.current.model,
            os_version: UIDevice.current.systemVersion,
            app_version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            build_number: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        )
    }

    private func getEnvironment() -> String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }

    private func startFlushTimer() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            Task { await self?.sendLogs() }
        }
    }

    @objc private func flushLogs() {
        Task { await sendLogs() }
    }

    private func sendLogs() async {
        guard !logQueue.isEmpty else { return }

        let logsToSend = logQueue
        logQueue = []

        do {
            try await supabase
                .from("app_logs")
                .insert(logsToSend)
                .execute()

            #if DEBUG
            print("📊 Sent \(logsToSend.count) logs to Supabase")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to send logs: \(error.localizedDescription)")
            #endif
            // Re-queue failed logs (limit to prevent memory issues)
            if logQueue.count < 100 {
                logQueue.insert(contentsOf: logsToSend, at: 0)
            }
        }
    }
}

// MARK: - Convenience Global Functions

/// Quick logging functions
@MainActor
func logDebug(_ message: String, function: String? = nil) {
    AppLoggingService.shared.debug(message, function: function)
}

@MainActor
func logInfo(_ message: String, function: String? = nil) {
    AppLoggingService.shared.info(message, function: function)
}

@MainActor
func logWarn(_ message: String, function: String? = nil) {
    AppLoggingService.shared.warn(message, function: function)
}

@MainActor
func logError(_ message: String, error: Error? = nil, function: String? = nil) {
    AppLoggingService.shared.error(message, error: error, function: function)
}
