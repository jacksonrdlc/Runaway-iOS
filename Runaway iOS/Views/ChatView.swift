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
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AppTheme.Spacing.md) {
                        if !viewModel.hasMessages {
                            // Welcome message
                            WelcomeView()
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
                .onChange(of: viewModel.messages.count) { _ in
                    // Scroll to bottom when new message arrives
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Suggested Prompts (when no messages)
            if !viewModel.hasMessages && !viewModel.isLoading {
                SuggestedPromptsView(
                    prompts: viewModel.suggestedPrompts,
                    onSelect: { prompt in
                        Task {
                            await viewModel.sendMessage(prompt)
                        }
                    }
                )
            }

            // Message Input
            MessageInputView(
                text: $messageText,
                isLoading: viewModel.isLoading,
                onSend: {
                    let message = messageText
                    messageText = ""  // Clear immediately for better UX
                    Task {
                        await viewModel.sendMessage(message)
                    }
                }
            )
            .focused($isMessageFieldFocused)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("AI Coach")
        .navigationBarTitleDisplayMode(.inline)
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
                        .foregroundColor(AppTheme.Colors.primary)
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
                .foregroundColor(AppTheme.Colors.primary)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("AI Running Coach")
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.primaryText)

                Text("Ask me anything about your training, get personalized advice, or request analysis of your performance.")
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.secondaryText)
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

    var body: some View {
        HStack {
            if isUser { Spacer() }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(AppTheme.Typography.body)
                    .foregroundColor(isUser ? .white : AppTheme.Colors.cardPrimaryText)
                    .padding(AppTheme.Spacing.md)
                    .background(isUser ? AppTheme.Colors.primary : AppTheme.Colors.cardBackground)
                    .cornerRadius(AppTheme.CornerRadius.medium)

                if let date = ISO8601DateFormatter().date(from: message.timestamp) {
                    Text(date, style: .time)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(AppTheme.Colors.mutedText)
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
                    .fill(AppTheme.Colors.primary)
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
        .background(AppTheme.Colors.cardBackground)
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
                .foregroundColor(AppTheme.Colors.secondaryText)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(prompts, id: \.self) { prompt in
                        Button(action: {
                            onSelect(prompt)
                        }) {
                            Text(prompt)
                                .font(AppTheme.Typography.body)
                                .foregroundColor(AppTheme.Colors.primary)
                                .padding(.horizontal, AppTheme.Spacing.md)
                                .padding(.vertical, AppTheme.Spacing.sm)
                                .background(AppTheme.Colors.primary.opacity(0.1))
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

// MARK: - Message Input View

struct MessageInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            FastTextInput(text: $text, placeholder: "Ask your coach...")
                .frame(minHeight: 44, maxHeight: 120)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(20)
                .disabled(isLoading)

            Button(action: {
                if !text.isEmpty && !isLoading {
                    onSend()
                }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(text.isEmpty || isLoading ? .gray : AppTheme.Colors.primary)
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.Colors.cardBackground)
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
                        .foregroundColor(AppTheme.Colors.primaryText)

                    Text("The coach has run an analysis for you. Check your Insights tab for detailed results.")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.secondaryText)

                    Button(action: {
                        dismiss()
                    }) {
                        Text("View in Insights")
                            .font(AppTheme.Typography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.Colors.primary)
                            .cornerRadius(AppTheme.CornerRadius.medium)
                    }
                }
                .padding()
            }
            .navigationTitle("Analysis Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
