//
//  ChatView.swift
//  Runaway iOS
//
//  Chat interface with AI Running Coach
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var showingAnalysisSheet = false
    @FocusState private var isMessageFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // iOS 26 Upgrade Banner (when AI not available)
            if viewModel.requiresUpgrade {
                iOS26UpgradeBanner()
            }

            // On-device AI indicator
            if viewModel.isUsingOnDeviceAI && !viewModel.requiresUpgrade {
                OnDeviceAIIndicator()
            }

            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AppTheme.Spacing.md) {
                        if !viewModel.hasMessages {
                            // Welcome message
                            if viewModel.requiresUpgrade {
                                UpgradeRequiredWelcomeView()
                            } else {
                                WelcomeView()
                            }
                        }

                        // Chat messages
                        ForEach(viewModel.messages) { message in
                            ChatMessageBubble(message: message)
                                .id(message.id)
                        }

                        // Loading indicator
                        if viewModel.isLoading {
                            TypingIndicator()
                        }
                    }
                    .padding()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // Dismiss keyboard when tapping messages area
                    isMessageFieldFocused = false
                }
                .onChange(of: viewModel.messages.count) { _ in
                    // Scroll to bottom when new message arrives
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Suggested Prompts (when no messages and AI available)
            if !viewModel.hasMessages && !viewModel.isLoading && !viewModel.requiresUpgrade {
                SuggestedPromptsView(
                    prompts: viewModel.suggestedPrompts,
                    onSelect: { prompt in
                        isMessageFieldFocused = false
                        Task {
                            await viewModel.sendMessage(prompt)
                        }
                    }
                )
            }

            // Message Input (disabled when upgrade required)
            MessageInputView(
                text: $messageText,
                isLoading: viewModel.isLoading,
                isDisabled: viewModel.requiresUpgrade,
                onSend: {
                    let message = messageText
                    messageText = ""  // Clear immediately for better UX
                    isMessageFieldFocused = false  // Dismiss keyboard after sending
                    Task {
                        await viewModel.sendMessage(message)
                    }
                }
            )
            .focused($isMessageFieldFocused)
        }
        .background(AppTheme.Colors.LightMode.background)
        .navigationTitle("AI Coach")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Re-check AI availability when view appears
            viewModel.refreshAIAvailability()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        viewModel.startNewConversation()
                    }) {
                        Label("New Conversation", systemImage: "plus.message")
                    }

                    if viewModel.conversationId != nil {
                        Button(role: .destructive, action: {
                            Task {
                                await viewModel.deleteCurrentConversation()
                            }
                        }) {
                            Label("Delete Conversation", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AppTheme.Colors.LightMode.accent)
                }
            }
        }
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.Colors.LightMode.accent)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("AI Running Coach")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                Text("Ask me anything about your training, get personalized advice, or request analysis of your performance.")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppTheme.Spacing.xl)
    }
}

// MARK: - Chat Message Bubble

struct ChatMessageBubble: View {
    let message: ChatMessage

    var isUser: Bool {
        message.role == "user"
    }

    /// Parse markdown content into AttributedString for rendering
    private var formattedContent: AttributedString {
        // For user messages, just return plain text
        if isUser {
            return AttributedString(message.content)
        }

        // For assistant messages, parse markdown
        do {
            var attributed = try AttributedString(markdown: message.content, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            // Apply default styling
            attributed.font = AppTheme.Typography.body
            attributed.foregroundColor = AppTheme.Colors.LightMode.textPrimary
            return attributed
        } catch {
            // Fallback to plain text if markdown parsing fails
            var plain = AttributedString(message.content)
            plain.font = AppTheme.Typography.body
            plain.foregroundColor = AppTheme.Colors.LightMode.textPrimary
            return plain
        }
    }

    var body: some View {
        HStack {
            if isUser { Spacer() }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if isUser {
                    Text(message.content)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(.white)
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.Colors.LightMode.accent)
                        .cornerRadius(AppTheme.CornerRadius.medium)
                } else {
                    Text(formattedContent)
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.Colors.LightMode.cardBackground)
                        .cornerRadius(AppTheme.CornerRadius.medium)
                }

                if let date = ISO8601DateFormatter().date(from: message.timestamp) {
                    Text(date, style: .time)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.LightMode.textTertiary)
                        .padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer() }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(AppTheme.Colors.LightMode.accent)
                    .frame(width: 8, height: 8)
                    .opacity(animating ? 0.3 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.LightMode.cardBackground)
        .cornerRadius(AppTheme.CornerRadius.medium)
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Suggested Prompts

struct SuggestedPromptsView: View {
    let prompts: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Suggestions")
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(prompts, id: \.self) { prompt in
                        Button(action: {
                            onSelect(prompt)
                        }) {
                            Text(prompt)
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.LightMode.accent)
                                .padding(.horizontal, AppTheme.Spacing.md)
                                .padding(.vertical, AppTheme.Spacing.sm)
                                .background(AppTheme.Colors.LightMode.accent.opacity(0.1))
                                .cornerRadius(AppTheme.CornerRadius.medium)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, AppTheme.Spacing.sm)
    }
}

// MARK: - iOS 26 Upgrade Banner

struct iOS26UpgradeBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("iOS 26 Required")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                Text("Upgrade to use on-device AI coaching")
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.Colors.LightMode.textTertiary)
                .font(.caption)
        }
        .padding(AppTheme.Spacing.md)
        .background(Color.orange.opacity(0.1))
    }
}

// MARK: - On-Device AI Indicator

struct OnDeviceAIIndicator: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.green)
                .font(.caption)

            Text("On-device AI")
                .font(.caption)
                .foregroundColor(AppTheme.Colors.LightMode.textSecondary)

            Text("Private & Offline")
                .font(.caption2)
                .foregroundColor(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.1))
                .cornerRadius(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.05))
    }
}

// MARK: - Upgrade Required Welcome View

struct UpgradeRequiredWelcomeView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
            }

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("AI Coach Coming Soon")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                Text("Your device needs iOS 26 or later to use on-device AI coaching. This feature uses Apple Intelligence to provide personalized, private coaching without sending data to external servers.")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.LightMode.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Feature benefits
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                FeatureBenefitRow(icon: "lock.shield.fill", text: "100% private - data stays on device")
                FeatureBenefitRow(icon: "wifi.slash", text: "Works completely offline")
                FeatureBenefitRow(icon: "bolt.fill", text: "Fast, instant responses")
                FeatureBenefitRow(icon: "figure.run", text: "Personalized to your training")
            }
            .padding(.top, AppTheme.Spacing.md)
        }
        .padding(AppTheme.Spacing.xl)
    }
}

struct FeatureBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.Colors.LightMode.accent)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(AppTheme.Colors.LightMode.textSecondary)

            Spacer()
        }
    }
}

// MARK: - Message Input View

struct MessageInputView: View {
    @Binding var text: String
    let isLoading: Bool
    var isDisabled: Bool = false
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            FastTextInput(text: $text, placeholder: isDisabled ? "Upgrade to iOS 26 to chat..." : "Ask your coach...")
                .frame(minHeight: 44, maxHeight: 120)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(20)
                .disabled(isLoading || isDisabled)
                .opacity(isDisabled ? 0.6 : 1.0)

            Button(action: {
                if !text.isEmpty && !isLoading && !isDisabled {
                    onSend()
                }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(text.isEmpty || isLoading || isDisabled ? .gray : AppTheme.Colors.LightMode.accent)
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty || isLoading || isDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.Colors.LightMode.cardBackground)
    }
}

// MARK: - Fast Text Input (UITextView wrapper without problematic gestures)

struct FastTextInput: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 16)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = true
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.returnKeyType = .default

        // Disable problematic gesture recognizers
        if let gestureRecognizers = textView.gestureRecognizers {
            for gesture in gestureRecognizers {
                // Disable drag and drop gestures that cause timeouts
                if gesture is UIDragInteraction ||
                   gesture is UIDropInteraction ||
                   String(describing: type(of: gesture)).contains("Drag") {
                    gesture.isEnabled = false
                }
            }
        }

        // Set placeholder
        updatePlaceholder(textView, isEmpty: text.isEmpty)

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            textView.text = text
        }
        updatePlaceholder(textView, isEmpty: text.isEmpty)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func updatePlaceholder(_ textView: UITextView, isEmpty: Bool) {
        if isEmpty {
            textView.text = placeholder
            textView.textColor = .secondaryLabel
        } else if textView.textColor == .secondaryLabel {
            textView.textColor = .label
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        let parent: FastTextInput

        init(_ parent: FastTextInput) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == .secondaryLabel {
                textView.text = ""
                textView.textColor = .label
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            if textView.textColor == .label {
                parent.text = textView.text
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                parent.updatePlaceholder(textView, isEmpty: true)
            }
        }
    }
}

// MARK: - Analysis Detail Sheet

struct AnalysisDetailSheet: View {
    let analysis: TriggeredAnalysis
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    Text("Analysis Type: \(analysis.type.capitalized)")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(AppTheme.Colors.LightMode.textPrimary)

                    Text("The coach has run an analysis for you. Check your Insights tab for detailed results.")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.LightMode.textSecondary)

                    Button(action: {
                        dismiss()
                    }) {
                        Text("View in Insights")
                            .font(AppTheme.Typography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.Colors.LightMode.accent)
                            .cornerRadius(AppTheme.CornerRadius.medium)
                    }
                }
                .padding()
            }
            .navigationTitle("Analysis Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.LightMode.accent)
                }
            }
        }
    }
}

// MARK: - Preview

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatView()
                .environmentObject(DataManager.shared)
        }
    }
}
