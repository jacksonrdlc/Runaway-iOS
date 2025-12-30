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

        #if DEBUG
        print("🆕 Started new conversation")
        #endif
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
