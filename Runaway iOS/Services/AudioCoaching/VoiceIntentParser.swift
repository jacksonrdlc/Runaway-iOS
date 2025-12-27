//
//  VoiceIntentParser.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation

// MARK: - Voice Intent

/// Recognized intents from voice input
enum VoiceIntent: Equatable {
    // Feeling responses (for check-ins)
    case feelingGreat
    case feelingGood
    case feelingOkay
    case feelingTired
    case feelingBad

    // Commands
    case requestStats
    case requestPace
    case requestDistance
    case requestTime
    case requestHeartRate

    // Control
    case pause
    case resume
    case stop
    case mute
    case unmute

    // Affirmative/Negative
    case yes
    case no

    // Unrecognized
    case unknown(String)

    // MARK: - Response Generation

    var acknowledgment: String {
        switch self {
        case .feelingGreat:
            return "Awesome! You're crushing it. Keep that energy going!"
        case .feelingGood:
            return "Great to hear. Stay steady."
        case .feelingOkay:
            return "Got it. Keep pushing."
        case .feelingTired:
            return "Noted. Listen to your body. Consider easing up if needed."
        case .feelingBad:
            return "Hang in there. It's okay to slow down or take a break."
        case .requestStats:
            return "" // Will be handled by generating actual stats
        case .requestPace, .requestDistance, .requestTime, .requestHeartRate:
            return "" // Will be handled with actual data
        case .pause:
            return "Pausing."
        case .resume:
            return "Resuming."
        case .stop:
            return "Stopping run."
        case .mute:
            return "Audio coaching muted."
        case .unmute:
            return "Audio coaching unmuted."
        case .yes:
            return "Got it."
        case .no:
            return "Okay, no problem."
        case .unknown:
            return "I didn't catch that."
        }
    }

    var isFeelingResponse: Bool {
        switch self {
        case .feelingGreat, .feelingGood, .feelingOkay, .feelingTired, .feelingBad:
            return true
        default:
            return false
        }
    }

    var isCommand: Bool {
        switch self {
        case .requestStats, .requestPace, .requestDistance, .requestTime, .requestHeartRate,
             .pause, .resume, .stop, .mute, .unmute:
            return true
        default:
            return false
        }
    }
}

// MARK: - Voice Intent Parser

/// Parses transcribed speech into actionable intents
struct VoiceIntentParser {

    // MARK: - Keyword Mappings

    private static let feelingGreatKeywords = [
        "great", "amazing", "awesome", "fantastic", "excellent", "incredible",
        "wonderful", "perfect", "strong", "powerful", "energized", "fired up"
    ]

    private static let feelingGoodKeywords = [
        "good", "fine", "well", "nice", "solid", "decent", "pretty good"
    ]

    private static let feelingOkayKeywords = [
        "okay", "ok", "alright", "so so", "not bad", "meh", "fair", "moderate"
    ]

    private static let feelingTiredKeywords = [
        "tired", "fatigued", "exhausted", "worn out", "drained", "sleepy",
        "heavy", "sluggish", "slow", "rough"
    ]

    private static let feelingBadKeywords = [
        "bad", "terrible", "awful", "horrible", "struggling", "hurting",
        "pain", "cramp", "sick", "nauseous", "dizzy", "can't"
    ]

    private static let statsKeywords = [
        "stats", "statistics", "status", "how am i doing", "update",
        "give me an update", "what's my"
    ]

    private static let paceKeywords = [
        "pace", "speed", "how fast", "what pace", "current pace"
    ]

    private static let distanceKeywords = [
        "distance", "how far", "miles", "kilometers", "how much"
    ]

    private static let timeKeywords = [
        "time", "how long", "duration", "elapsed", "clock"
    ]

    private static let heartRateKeywords = [
        "heart rate", "heart", "hr", "bpm", "pulse", "zone"
    ]

    private static let pauseKeywords = [
        "pause", "stop recording", "hold", "wait", "break"
    ]

    private static let resumeKeywords = [
        "resume", "continue", "go", "start", "unpause"
    ]

    private static let stopKeywords = [
        "stop", "end", "finish", "done", "complete", "end run"
    ]

    private static let muteKeywords = [
        "mute", "quiet", "silence", "shut up", "stop talking", "no more audio"
    ]

    private static let unmuteKeywords = [
        "unmute", "talk", "speak", "audio on", "start talking"
    ]

    private static let yesKeywords = [
        "yes", "yeah", "yep", "yup", "sure", "absolutely", "definitely",
        "correct", "right", "affirmative", "uh huh"
    ]

    private static let noKeywords = [
        "no", "nope", "nah", "negative", "not really", "don't"
    ]

    // MARK: - Parsing

    /// Parse a transcript into an intent
    static func parse(_ transcript: String) -> VoiceIntent {
        let lowercased = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check in order of specificity

        // Commands first (more specific)
        if containsAny(lowercased, keywords: stopKeywords) && lowercased.contains("run") {
            return .stop
        }

        if containsAny(lowercased, keywords: muteKeywords) {
            return .mute
        }

        if containsAny(lowercased, keywords: unmuteKeywords) {
            return .unmute
        }

        if containsAny(lowercased, keywords: pauseKeywords) {
            return .pause
        }

        if containsAny(lowercased, keywords: resumeKeywords) {
            return .resume
        }

        // Stats requests
        if containsAny(lowercased, keywords: heartRateKeywords) {
            return .requestHeartRate
        }

        if containsAny(lowercased, keywords: paceKeywords) {
            return .requestPace
        }

        if containsAny(lowercased, keywords: distanceKeywords) {
            return .requestDistance
        }

        if containsAny(lowercased, keywords: timeKeywords) {
            return .requestTime
        }

        if containsAny(lowercased, keywords: statsKeywords) {
            return .requestStats
        }

        // Feeling responses (check negative feelings first - more specific)
        if containsAny(lowercased, keywords: feelingBadKeywords) {
            return .feelingBad
        }

        if containsAny(lowercased, keywords: feelingTiredKeywords) {
            return .feelingTired
        }

        if containsAny(lowercased, keywords: feelingGreatKeywords) {
            return .feelingGreat
        }

        if containsAny(lowercased, keywords: feelingGoodKeywords) {
            return .feelingGood
        }

        if containsAny(lowercased, keywords: feelingOkayKeywords) {
            return .feelingOkay
        }

        // Yes/No
        if containsAny(lowercased, keywords: yesKeywords) {
            return .yes
        }

        if containsAny(lowercased, keywords: noKeywords) {
            return .no
        }

        // Unknown
        return .unknown(transcript)
    }

    /// Parse with context (e.g., what prompt was just asked)
    static func parse(_ transcript: String, context: ConversationContext?) -> VoiceIntent {
        let intent = parse(transcript)

        // If we have context, we can be smarter about interpretation
        guard let context = context else { return intent }

        switch context.lastPromptType {
        case .checkIn:
            // For check-ins, try to interpret as feeling if unknown
            if case .unknown(let text) = intent {
                // Try fuzzy matching for feelings
                return fuzzyMatchFeeling(text) ?? intent
            }

        case .some:
            // Other prompt types might need different handling
            break

        case .none:
            break
        }

        return intent
    }

    // MARK: - Helpers

    private static func containsAny(_ text: String, keywords: [String]) -> Bool {
        for keyword in keywords {
            if text.contains(keyword) {
                return true
            }
        }
        return false
    }

    private static func fuzzyMatchFeeling(_ text: String) -> VoiceIntent? {
        // Simple sentiment analysis for unknown responses
        let positive = ["!", "love", "enjoy", "happy", "smile"]
        let negative = ["ugh", "hard", "tough", "struggle", "help"]

        let hasPositive = containsAny(text, keywords: positive)
        let hasNegative = containsAny(text, keywords: negative)

        if hasPositive && !hasNegative {
            return .feelingGood
        } else if hasNegative && !hasPositive {
            return .feelingTired
        }

        return nil
    }
}

// MARK: - Conversation Context

/// Tracks conversation state for contextual parsing
final class ConversationContext: ObservableObject {

    @Published var lastPromptType: PromptType?
    @Published var lastPromptTime: Date?
    @Published var pendingResponse: Bool = false
    @Published var conversationHistory: [ConversationTurn] = []

    /// Maximum turns to keep in history
    private let maxHistorySize = 10

    /// Add a prompt to the conversation
    func addPrompt(_ prompt: QueuedPrompt) {
        lastPromptType = prompt.type
        lastPromptTime = Date()
        pendingResponse = prompt.expectsResponse

        let turn = ConversationTurn(
            role: .coach,
            content: prompt.message,
            promptType: prompt.type,
            timestamp: Date()
        )
        addTurn(turn)
    }

    /// Add a user response to the conversation
    func addResponse(_ transcript: String, intent: VoiceIntent) {
        pendingResponse = false

        let turn = ConversationTurn(
            role: .runner,
            content: transcript,
            intent: intent,
            timestamp: Date()
        )
        addTurn(turn)
    }

    /// Check if we're expecting a response
    var isExpectingResponse: Bool {
        guard pendingResponse, let promptTime = lastPromptTime else {
            return false
        }
        // Response window is 30 seconds
        return Date().timeIntervalSince(promptTime) < 30
    }

    /// Reset context for new run
    func reset() {
        lastPromptType = nil
        lastPromptTime = nil
        pendingResponse = false
        conversationHistory.removeAll()
    }

    private func addTurn(_ turn: ConversationTurn) {
        conversationHistory.append(turn)

        // Trim history
        if conversationHistory.count > maxHistorySize {
            conversationHistory.removeFirst()
        }
    }
}

// MARK: - Conversation Turn

struct ConversationTurn {
    enum Role {
        case coach
        case runner
    }

    let role: Role
    let content: String
    var promptType: PromptType?
    var intent: VoiceIntent?
    let timestamp: Date
}
