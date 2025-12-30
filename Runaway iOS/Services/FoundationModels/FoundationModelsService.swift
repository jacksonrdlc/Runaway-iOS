//
//  FoundationModelsService.swift
//  Runaway iOS
//
//  On-device AI service using Apple Foundation Models (iOS 26+)
//  Provides local LLM capabilities for chat and analysis without cloud dependency
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Service for on-device AI using Apple Foundation Models
/// Requires iOS 26+ - no cloud fallback per design decision
@MainActor
class FoundationModelsService: ObservableObject {
    static let shared = FoundationModelsService()

    // MARK: - Published Properties

    @Published private(set) var isAvailable: Bool = false
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var lastError: FoundationModelsError?

    // MARK: - Private Properties

    // Session stored as Any to avoid @available issues with stored properties
    private var _session: Any?

    // MARK: - Initialization

    private init() {
        #if DEBUG
        print("🧠 FoundationModelsService: Initializing...")
        #endif
        checkAvailability()
    }

    // MARK: - Availability Check

    /// Check if Foundation Models is available on this device
    func checkAvailability() {
        #if canImport(FoundationModels)
        #if DEBUG
        print("🧠 Foundation Models: SDK available (canImport succeeded)")
        #endif
        if #available(iOS 26.0, *) {
            #if DEBUG
            print("🧠 Foundation Models: iOS 26+ runtime check passed")
            #endif
            // Check actual model availability asynchronously
            Task { @MainActor in
                await self.checkModelAvailability()
            }
        } else {
            isAvailable = false
            #if DEBUG
            print("🧠 Foundation Models: iOS version < 26 (runtime)")
            #endif
        }
        #else
        // SDK doesn't include FoundationModels - need Xcode 26+
        isAvailable = false
        #if DEBUG
        print("🧠 Foundation Models: SDK does NOT include FoundationModels framework")
        print("   Compile with Xcode 26+ to enable on-device AI")
        #endif
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func checkModelAvailability() async {
        #if DEBUG
        print("🧠 Foundation Models: Checking model availability...")
        #endif

        // Check if the system language model is available
        let availability = SystemLanguageModel.default.availability

        #if DEBUG
        print("🧠 Foundation Models: Availability = \(availability)")
        #endif

        switch availability {
        case .available:
            isAvailable = true
            #if DEBUG
            print("🧠 Foundation Models: ✅ Available and ready!")
            #endif
        case .unavailable:
            isAvailable = false
            #if DEBUG
            print("🧠 Foundation Models: ❌ Unavailable on this device")
            print("   This could mean:")
            print("   - Apple Intelligence is not enabled in Settings")
            print("   - Device doesn't support Apple Intelligence")
            print("   - Model is still downloading")
            #endif
        @unknown default:
            isAvailable = false
            #if DEBUG
            print("🧠 Foundation Models: ❓ Unknown availability state")
            #endif
        }
    }
    #endif

    // MARK: - Text Generation

    /// Generate a response using on-device AI
    /// - Parameters:
    ///   - prompt: The prompt/question to send to the model
    ///   - systemPrompt: Optional system prompt for context
    ///   - maxTokens: Maximum tokens in response
    /// - Returns: Generated text response
    func generateResponse(
        prompt: String,
        systemPrompt: String? = nil,
        maxTokens: Int = 1024
    ) async throws -> String {
        guard isAvailable else {
            throw FoundationModelsError.notAvailable
        }

        isProcessing = true
        lastError = nil

        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await generateWithFoundationModels(
                prompt: prompt,
                systemPrompt: systemPrompt,
                maxTokens: maxTokens
            )
        }
        #endif

        throw FoundationModelsError.notAvailable
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateWithFoundationModels(
        prompt: String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        do {
            // Create session with system prompt as instructions
            let session: LanguageModelSession
            if let systemPrompt = systemPrompt {
                session = LanguageModelSession(instructions: systemPrompt)
            } else {
                session = LanguageModelSession()
            }

            // Generate response - respond returns Response<String> which contains the content
            let response = try await session.respond(to: prompt)

            #if DEBUG
            print("🧠 On-device response generated successfully")
            #endif

            // Access the content property of the Response
            return response.content
        } catch {
            #if DEBUG
            print("🧠 Foundation Models error: \(error)")
            #endif
            throw FoundationModelsError.generationFailed(error)
        }
    }
    #endif

    // MARK: - Running Coach Prompts

    /// Generate a running coach response for chat
    func generateCoachResponse(
        message: String,
        athleteContext: AthleteContext? = nil,
        recentActivities: [ActivitySummary]? = nil
    ) async throws -> String {
        let systemPrompt = buildRunningCoachSystemPrompt(
            athleteContext: athleteContext,
            recentActivities: recentActivities
        )

        return try await generateResponse(
            prompt: message,
            systemPrompt: systemPrompt,
            maxTokens: 2048
        )
    }

    /// Generate post-run analysis
    func generateActivityAnalysis(activity: ActivitySummary) async throws -> String {
        let prompt = """
        Analyze this running activity and provide personalized feedback:

        Distance: \(String(format: "%.2f", activity.distanceMiles)) miles
        Duration: \(formatDuration(activity.durationSeconds))
        Average Pace: \(activity.averagePace)
        \(activity.elevationGain.map { "Elevation Gain: \(Int($0)) ft" } ?? "")
        \(activity.averageHeartRate.map { "Average HR: \($0) bpm" } ?? "")

        Provide:
        1. Overall assessment
        2. What went well
        3. Areas for improvement
        4. Suggested next workout
        """

        let systemPrompt = "You are an expert running coach providing personalized feedback. Be encouraging but honest. Keep responses concise and actionable."

        return try await generateResponse(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: 1024
        )
    }

    /// Generate training suggestions based on recent activities
    func generateTrainingSuggestions(
        recentActivities: [ActivitySummary],
        goal: GoalSummary?
    ) async throws -> String {
        var prompt = "Based on my recent training:\n\n"

        for (index, activity) in recentActivities.prefix(5).enumerated() {
            prompt += "\(index + 1). \(activity.distanceMiles) mi @ \(activity.averagePace) pace\n"
        }

        if let goal = goal {
            prompt += "\nMy goal: \(goal.description)\n"
        }

        prompt += "\nWhat should my training focus be this week?"

        let systemPrompt = "You are an expert running coach. Provide specific, actionable training recommendations. Consider recovery, progressive overload, and variety."

        return try await generateResponse(
            prompt: prompt,
            systemPrompt: systemPrompt,
            maxTokens: 1024
        )
    }

    // MARK: - Private Helpers

    private func buildRunningCoachSystemPrompt(
        athleteContext: AthleteContext?,
        recentActivities: [ActivitySummary]?
    ) -> String {
        var prompt = """
        You are Runaway Coach, an expert AI running coach. You provide personalized training advice, motivation, and analysis.

        Guidelines:
        - Be encouraging but honest
        - Provide specific, actionable advice
        - Consider the athlete's fitness level and goals
        - Prioritize injury prevention and recovery
        - Keep responses concise and conversational
        """

        if let athlete = athleteContext {
            prompt += "\n\nAthlete Profile:"
            if let weeklyMileage = athlete.weeklyMileage {
                prompt += "\n- Weekly mileage: \(String(format: "%.1f", weeklyMileage)) miles"
            }
            if let goal = athlete.currentGoal {
                prompt += "\n- Current goal: \(goal)"
            }
        }

        if let activities = recentActivities, !activities.isEmpty {
            prompt += "\n\nRecent Activities:"
            for activity in activities.prefix(3) {
                prompt += "\n- \(activity.distanceMiles) mi @ \(activity.averagePace)"
            }
        }

        return prompt
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Error Types

enum FoundationModelsError: LocalizedError {
    case notAvailable
    case modelNotReady
    case generationFailed(Error)
    case invalidPrompt
    case tokenLimitExceeded

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "On-device AI requires iOS 26 or later. Please upgrade to use AI features."
        case .modelNotReady:
            return "The AI model is still downloading. Please try again later."
        case .generationFailed(let error):
            return "Failed to generate response: \(error.localizedDescription)"
        case .invalidPrompt:
            return "Invalid prompt provided"
        case .tokenLimitExceeded:
            return "Response exceeded maximum length"
        }
    }

    var requiresUpgrade: Bool {
        switch self {
        case .notAvailable:
            return true
        default:
            return false
        }
    }
}

// MARK: - Supporting Types

struct AthleteContext {
    let weeklyMileage: Double?
    let currentGoal: String?
    let fitnessLevel: String?
}

struct ActivitySummary {
    let distanceMiles: Double
    let durationSeconds: TimeInterval
    let averagePace: String
    let elevationGain: Double?
    let averageHeartRate: Int?

    init(from activity: Activity) {
        self.distanceMiles = (activity.distance ?? 0) * 0.000621371
        self.durationSeconds = activity.elapsed_time ?? 0

        // Calculate pace
        if let speed = activity.average_speed, speed > 0 {
            let minutesPerMile = (1609.34 / speed) / 60.0
            let minutes = Int(minutesPerMile)
            let seconds = Int((minutesPerMile - Double(minutes)) * 60)
            self.averagePace = String(format: "%d:%02d /mi", minutes, seconds)
        } else {
            self.averagePace = "--:-- /mi"
        }

        self.elevationGain = activity.elevation_gain.map { $0 * 3.28084 } // Convert to feet
        self.averageHeartRate = activity.average_heart_rate
    }
}

struct GoalSummary {
    let type: String
    let description: String
    let deadline: Date?
}
