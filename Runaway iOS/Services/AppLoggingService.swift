//
//  AppLoggingService.swift
//  Runaway iOS
//
//  Centralized logging service that sends logs to Supabase
//

import Foundation
import UIKit

/// Log levels for categorizing log messages
enum LogLevel: String, Codable {
    case debug = "debug"
    case info = "info"
    case warn = "warn"
    case error = "error"
}

/// Log entry structure matching Supabase table
struct AppLogEntry: Codable {
    let source: String
    let function_name: String?
    let level: String
    let message: String
    let user_id: String?
    let athlete_id: Int?
    let session_id: String?
    let request_method: String?
    let request_path: String?
    let request_body: [String: AnyCodable]?
    let response_status: Int?
    let response_body: [String: AnyCodable]?
    let duration_ms: Int?
    let error_message: String?
    let error_stack: String?
    let device_info: DeviceInfo?
    let environment: String
    let metadata: [String: AnyCodable]?
}

struct DeviceInfo: Codable {
    let model: String
    let os_version: String
    let app_version: String
    let build_number: String
}

/// Wrapper for encoding arbitrary JSON values
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

/// Centralized logging service for the app
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
    func debug(_ message: String, function: String? = nil, metadata: [String: Any]? = nil) {
        log(level: .debug, message: message, functionName: function, metadata: metadata)
    }

    /// Log an info message
    func info(_ message: String, function: String? = nil, metadata: [String: Any]? = nil) {
        log(level: .info, message: message, functionName: function, metadata: metadata)
    }

    /// Log a warning
    func warn(_ message: String, function: String? = nil, metadata: [String: Any]? = nil) {
        log(level: .warn, message: message, functionName: function, metadata: metadata)
    }

    /// Log an error
    func error(_ message: String, error: Error? = nil, function: String? = nil, metadata: [String: Any]? = nil) {
        var meta = metadata ?? [:]
        if let error = error {
            meta["error_type"] = String(describing: type(of: error))
        }
        log(
            level: .error,
            message: message,
            functionName: function,
            errorMessage: error?.localizedDescription,
            errorStack: (error as NSError?)?.userInfo.description,
            metadata: meta
        )
    }

    /// Log an API request
    func logRequest(
        method: String,
        path: String,
        body: [String: Any]? = nil,
        function: String? = nil
    ) {
        log(
            level: .info,
            message: "API Request: \(method) \(path)",
            functionName: function,
            requestMethod: method,
            requestPath: path,
            requestBody: body
        )
    }

    /// Log an API response
    func logResponse(
        method: String,
        path: String,
        status: Int,
        body: [String: Any]? = nil,
        durationMs: Int? = nil,
        function: String? = nil
    ) {
        let level: LogLevel = (200...299).contains(status) ? .info : .error
        log(
            level: level,
            message: "API Response: \(method) \(path) - \(status)",
            functionName: function,
            requestMethod: method,
            requestPath: path,
            responseStatus: status,
            responseBody: body,
            durationMs: durationMs
        )
    }

    /// Log authentication event
    func logAuth(event: String, userId: String? = nil, metadata: [String: Any]? = nil) {
        var meta = metadata ?? [:]
        meta["auth_event"] = event
        log(
            level: .info,
            message: "Auth: \(event)",
            functionName: "Auth",
            metadata: meta
        )
    }

    // MARK: - Private Methods

    private func log(
        level: LogLevel,
        message: String,
        functionName: String? = nil,
        requestMethod: String? = nil,
        requestPath: String? = nil,
        requestBody: [String: Any]? = nil,
        responseStatus: Int? = nil,
        responseBody: [String: Any]? = nil,
        durationMs: Int? = nil,
        errorMessage: String? = nil,
        errorStack: String? = nil,
        metadata: [String: Any]? = nil
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
            user_id: UserSession.shared.userId?.uuidString,
            athlete_id: DataManager.shared.athlete?.id,
            session_id: sessionId,
            request_method: requestMethod,
            request_path: requestPath,
            request_body: requestBody?.mapValues { AnyCodable($0) },
            response_status: responseStatus,
            response_body: responseBody?.mapValues { AnyCodable($0) },
            duration_ms: durationMs,
            error_message: errorMessage,
            error_stack: errorStack,
            device_info: getDeviceInfo(),
            environment: getEnvironment(),
            metadata: metadata?.mapValues { AnyCodable($0) }
        )

        logQueue.append(entry)

        // Flush if batch size reached or error level
        if logQueue.count >= batchSize || level == .error {
            Task { await sendLogs() }
        }
    }

    private func getDeviceInfo() -> DeviceInfo {
        DeviceInfo(
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
func logDebug(_ message: String, function: String? = nil) {
    AppLoggingService.shared.debug(message, function: function)
}

func logInfo(_ message: String, function: String? = nil) {
    AppLoggingService.shared.info(message, function: function)
}

func logWarn(_ message: String, function: String? = nil) {
    AppLoggingService.shared.warn(message, function: function)
}

func logError(_ message: String, error: Error? = nil, function: String? = nil) {
    AppLoggingService.shared.error(message, error: error, function: function)
}
