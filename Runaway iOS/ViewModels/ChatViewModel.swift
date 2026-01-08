//
//  ChatViewModel.swift
//  Runaway iOS
//
//  ViewModel for Chat with AI Running Coach
//

import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var messages: [ChatMessage] = []
    @Published var conversationId: String?
    @Published var isLoading = false
    @Published var error: ChatError?
    @Published var triggeredAnalysis: TriggeredAnalysis?
    @Published var requiresUpgrade = false  // True when iOS 26+ is required
    @Published var isUsingOnDeviceAI = false  // True when using Foundation Models

    // MARK: - Dependencies

    private let dataManager: DataManager

    // MARK: - Initialization

    init(dataManager: DataManager = DataManager.shared) {
        self.dataManager = dataManager
        // Check if on-device AI is available
        checkAIAvailability()
    }

    // MARK: - AI Availability

    /// Check if on-device AI is available (iOS 26+)
    func checkAIAvailability() {
        isUsingOnDeviceAI = FoundationModelsService.shared.isAvailable
        requiresUpgrade = !isUsingOnDeviceAI

        #if DEBUG
        print("💬 ChatViewModel: isUsingOnDeviceAI = \(isUsingOnDeviceAI), requiresUpgrade = \(requiresUpgrade)")
        #endif
    }

    /// Re-check AI availability (called when view appears)
    func refreshAIAvailability() {
        // Re-trigger the availability check
        FoundationModelsService.shared.checkAvailability()

        // Wait a moment for async check to complete, then update state
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            checkAIAvailability()
        }
    }

    // MARK: - Proactive Greeting (Fitness Concierge)

    @Published var hasGeneratedGreeting = false

    /// Generate a proactive, inspiring greeting based on recent activities
    /// Called when the coach tab is opened and there are no messages
    /// This is INSTANT - no API call, just local personalization
    func generateProactiveGreeting() async {
        // Don't generate if we already have messages or already generated
        guard messages.isEmpty && !hasGeneratedGreeting && !requiresUpgrade else { return }

        hasGeneratedGreeting = true

        // Instant greeting - no waiting, no loading state
        let greeting = buildFallbackGreeting()
        let greetingMessage = ChatMessage(
            role: "assistant",
            content: greeting
        )
        messages.append(greetingMessage)

        #if DEBUG
        print("✨ Generated instant proactive greeting")
        #endif
    }

    /// Build context for the proactive greeting
    private func buildGreetingContext(from activities: [Activity]) -> (prompt: String, athleteContext: ChatContext) {
        let athleteContext = ChatService.buildContext(
            from: dataManager.activities,
            goal: dataManager.currentGoal,
            athlete: dataManager.athlete
        )

        // Build a prompt that asks the AI to be a proactive fitness concierge
        var prompt = """
        [SYSTEM: You are greeting the user as they open the coach tab. You are not just a coach — you're a mirror that believes in them before they do.

        Your purpose: \(MissionProvider.shared.mission)

        Core belief: \(MissionProvider.shared.beliefs)

        Your role: You reflect back who they're becoming, especially when they can't see it themselves. You see their trajectory, their patterns, the gap between what they believe about themselves and what their own data proves is possible.

        Generate a personalized greeting that:
        1. Reflects positively on their recent training — see what they might not see in themselves
        2. Offers an observation about their progress that shows you believe in their potential
        3. Ends with an invitation to talk, not just "how can I help" but genuine curiosity about where they're at

        Keep it concise (2-3 short paragraphs). Be warm and authentic. Don't be generic or overly enthusiastic — be real.]

        """

        // Add recent activity summary
        if !activities.isEmpty {
            let thisWeek = activities.filter { activity in
                guard let timestamp = activity.activity_date ?? activity.start_date else { return false }
                let activityDate = Date(timeIntervalSince1970: timestamp)
                return Calendar.current.isDate(activityDate, equalTo: Date(), toGranularity: .weekOfYear)
            }

            let totalMiles = thisWeek.reduce(0.0) { sum, activity in
                sum + (activity.distance ?? 0) * 0.000621371
            }

            let activityCount = thisWeek.count

            if activityCount > 0 {
                prompt += "\n\nThis week: \(activityCount) activities, \(String(format: "%.1f", totalMiles)) miles total."
            }

            // Add last activity details
            if let lastActivity = activities.first {
                let miles = (lastActivity.distance ?? 0) * 0.000621371
                let name = lastActivity.name ?? "Activity"
                prompt += "\nMost recent: \(name) - \(String(format: "%.1f", miles)) miles"

                if let timestamp = lastActivity.activity_date ?? lastActivity.start_date {
                    let date = Date(timeIntervalSince1970: timestamp)
                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .short
                    prompt += " (\(formatter.localizedString(for: date, relativeTo: Date())))"
                }
            }
        } else {
            prompt += "\n\nNo recent activities found - this might be a new user or someone returning after a break."
        }

        prompt += "\n\nGenerate your greeting now:"

        return (prompt, athleteContext)
    }

    /// Fallback greeting when API fails
    private func buildFallbackGreeting() -> String {
        let activities = dataManager.activities.prefix(5)

        if activities.isEmpty {
            return """
            Hey. 👋

            I'm here — not just as a coach, but as a mirror. My job is to reflect back who you're becoming, especially when you can't see it yourself.

            Whether you're just starting out or finding your way back, every step forward is an act of self-definition. What's on your mind today?
            """
        } else {
            let thisWeekCount = activities.filter { activity in
                guard let timestamp = activity.activity_date ?? activity.start_date else { return false }
                let activityDate = Date(timeIntervalSince1970: timestamp)
                return Calendar.current.isDate(activityDate, equalTo: Date(), toGranularity: .weekOfYear)
            }.count

            if thisWeekCount > 0 {
                return """
                Hey. 👋

                \(thisWeekCount) \(thisWeekCount == 1 ? "run" : "runs") this week. You're showing up — and that's not nothing. That's exactly how you become someone different than who you thought you were.

                I've been looking at your recent training. What are you feeling? What's working, what's not? I'm curious where your head is at.
                """
            } else {
                return """
                Hey. 👋

                It's been a minute since your last run. That's okay — sometimes life gets in the way, sometimes we need the break. What matters is you're here now.

                When you're ready, I'm ready. What's going on? Want to ease back in, or talk through what's been holding you back?
                """
            }
        }
    }

    // MARK: - Public Methods

    /// Send a message to the AI coach
    func sendMessage(_ text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Add user message to UI immediately
        let userMessage = ChatMessage(role: "user", content: text)
        messages.append(userMessage)

        // Track analytics
        AnalyticsService.shared.trackChatMessage(
            messageLength: text.count,
            hasContext: dataManager.activities.count > 0
        )

        isLoading = true
        error = nil

        do {
            // Build context from current app state
            let context = ChatService.buildContext(
                from: dataManager.activities,
                goal: dataManager.currentGoal,
                athlete: dataManager.athlete
            )

            // Send message to API
            let response = try await ChatService.sendMessage(
                message: text,
                conversationId: conversationId,
                context: context
            )

            #if DEBUG
            print("💬 Chat Response:")
            print("   Success: \(response.success)")
            print("   Message: \(response.message)")
            print("   Conversation ID: \(response.conversationId)")
            if let error = response.errorMessage {
                print("   Error: \(error)")
            }
            #endif

            // Check if API returned an error
            if !response.success {
                throw ChatError.serverError(response.errorMessage ?? response.message)
            }

            // Update conversation ID
            conversationId = response.conversationId

            // Add assistant response to UI
            let assistantMessage = ChatMessage(
                role: "assistant",
                content: response.message
            )
            messages.append(assistantMessage)

            // Track analytics
            AnalyticsService.shared.track(.chatResponseReceived, category: .chat, properties: [
                "response_length": response.message.count,
                "has_triggered_analysis": response.triggeredAnalysis != nil
            ])

            // Handle triggered analysis
            if let analysis = response.triggeredAnalysis {
                triggeredAnalysis = analysis
            }

        } catch let chatError as ChatError {
            self.error = chatError

            // Check if this is an iOS 26 requirement error
            if chatError.requiresUpgrade {
                requiresUpgrade = true

                // Track analytics
                AnalyticsService.shared.track(.chatError, category: .chat, properties: [
                    "error_type": "requires_ios26",
                    "error_message": chatError.localizedDescription
                ])

                // Add upgrade message to chat
                let upgradeMessage = ChatMessage(
                    role: "assistant",
                    content: "AI Coach requires iOS 26 or later to use on-device intelligence. Please upgrade your device to access personalized coaching features."
                )
                messages.append(upgradeMessage)
            } else {
                // Track analytics
                AnalyticsService.shared.track(.chatError, category: .chat, properties: [
                    "error_type": "chat_error",
                    "error_message": chatError.localizedDescription
                ])

                // Add error message to chat
                let errorMessage = ChatMessage(
                    role: "assistant",
                    content: "Sorry, I couldn't process that. Please try again."
                )
                messages.append(errorMessage)
            }

            #if DEBUG
            print("❌ Chat Error: \(chatError.localizedDescription)")
            #endif
        } catch {
            self.error = .networkError(error)

            // Track analytics
            AnalyticsService.shared.track(.chatError, category: .chat, properties: [
                "error_type": "network_error",
                "error_message": error.localizedDescription
            ])

            let errorMessage = ChatMessage(
                role: "assistant",
                content: "Sorry, I couldn't process that. Please try again."
            )
            messages.append(errorMessage)

            #if DEBUG
            print("❌ Unknown Error: \(error.localizedDescription)")
            #endif
        }

        isLoading = false
    }

    /// Load conversation history
    func loadConversation(id: String) async {
        isLoading = true
        error = nil

        do {
            let conversation = try await ChatService.getConversation(id: id)
            self.conversationId = conversation.id
            self.messages = conversation.messages

            #if DEBUG
            print("✅ Loaded conversation with \(messages.count) messages")
            #endif
        } catch let chatError as ChatError {
            self.error = chatError

            #if DEBUG
            print("❌ Failed to load conversation: \(chatError.localizedDescription)")
            #endif
        } catch {
            self.error = .networkError(error)
        }

        isLoading = false
    }

    /// Start a new conversation
    func startNewConversation() {
        messages = []
        conversationId = nil
        error = nil
        triggeredAnalysis = nil
        hasGeneratedGreeting = false  // Allow new greeting

        #if DEBUG
        print("🆕 Started new conversation")
        #endif

        // Generate a fresh greeting for the new conversation
        Task {
            await generateProactiveGreeting()
        }
    }

    /// Delete current conversation
    func deleteCurrentConversation() async {
        guard let id = conversationId else { return }

        do {
            try await ChatService.deleteConversation(id: id)
            startNewConversation()

            #if DEBUG
            print("✅ Deleted conversation")
            #endif
        } catch let chatError as ChatError {
            self.error = chatError

            #if DEBUG
            print("❌ Failed to delete conversation: \(chatError.localizedDescription)")
            #endif
        } catch {
            self.error = .networkError(error)
        }
    }

    /// Clear triggered analysis
    func clearTriggeredAnalysis() {
        triggeredAnalysis = nil
    }

    // MARK: - Suggested Prompts

    var suggestedPrompts: [String] {
        if messages.isEmpty {
            return [
                "How am I doing with my training?",
                "What should my easy run pace be?",
                "Can you analyze my recent runs?",
                "Create a training plan for me"
            ]
        } else {
            return [
                "Tell me more",
                "What else should I focus on?",
                "How can I improve?"
            ]
        }
    }

    // MARK: - Helpers

    var hasMessages: Bool {
        !messages.isEmpty
    }

    var canSendMessage: Bool {
        !isLoading
    }
}
