//
//  ForgotPasswordView.swift
//  Runaway iOS
//
//  Password reset flow
//

import SwiftUI
import Supabase

struct ForgotPasswordView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: ForgotPasswordViewModel

    @State private var showSuccess = false
    @State private var showError = false

    init(initialEmail: String = "") {
        _viewModel = StateObject(wrappedValue: ForgotPasswordViewModel(email: initialEmail))
    }

    private var backgroundColor: Color {
        themeManager.isDarkMode
            ? AppTheme.Colors.DarkMode.background
            : AppTheme.Colors.LightMode.background
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            // Dismiss keyboard on tap
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    Spacer()
                        .frame(height: AppTheme.Spacing.xl * 2)

                    // Header
                    VStack(spacing: AppTheme.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.Colors.accent.opacity(0.15))
                                .frame(width: 80, height: 80)

                            Image(systemName: "lock.rotation")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(AppTheme.Colors.accent)
                        }

                        Text("Reset Password")
                            .font(AppTheme.Typography.title)
                            .fontWeight(.bold)

                        Text("Enter your email address and we'll send you a link to reset your password.")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                    }

                    Spacer()
                        .frame(height: AppTheme.Spacing.xl)

                    // Email field
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("Email")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(.secondary)

                        AuthTextField(
                            text: $viewModel.email,
                            placeholder: "Enter your email",
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress
                        )
                        .onChange(of: viewModel.email) { _, _ in
                            viewModel.validateEmail()
                        }

                        if let error = viewModel.emailError {
                            ValidationMessage(message: error, type: .error)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    // Send reset link button
                    AuthButton(
                        title: "Send Reset Link",
                        action: { sendResetLink() },
                        style: .primary,
                        isEnabled: viewModel.isFormValid,
                        isLoading: viewModel.isLoading
                    )
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    Spacer()

                    // Back to sign in
                    AuthLinkButton(
                        text: "Remember your password?",
                        actionText: "Sign in",
                        action: { dismiss() }
                    )
                    .padding(.bottom, AppTheme.Spacing.xl)
                }
                .frame(minHeight: UIScreen.main.bounds.height - 150)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
        .alert("Check Your Email", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("We've sent a password reset link to \(viewModel.email). Please check your inbox.")
        }
        .alert("Reset Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }

    private func sendResetLink() {
        Task {
            do {
                try await viewModel.sendResetLink()
                showSuccess = true
            } catch {
                showError = true
            }
        }
    }
}

// MARK: - Forgot Password View Model

@MainActor
class ForgotPasswordViewModel: ObservableObject {
    @Published var email: String
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var emailError: String?

    var isFormValid: Bool {
        ValidationUtils.isValidEmail(email)
    }

    init(email: String = "") {
        self.email = email
    }

    func validateEmail() {
        if email.isEmpty {
            emailError = nil
        } else {
            emailError = ValidationUtils.emailValidationMessage(email)
        }
    }

    func sendResetLink() async throws {
        validateEmail()

        guard isFormValid else {
            throw AuthError(type: .invalidForm)
        }

        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.resetPasswordForEmail(email.trimmed)
        } catch {
            let authError = AuthError.from(error)
            errorMessage = authError.localizedDescription
            isLoading = false
            throw authError
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView(initialEmail: "test@example.com")
            .environmentObject(ThemeManager.shared)
    }
}
