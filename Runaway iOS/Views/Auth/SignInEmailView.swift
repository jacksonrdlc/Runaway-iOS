//
//  SignInEmailView.swift
//  Runaway iOS
//
//  Email sign-in view with validation and forgot password flow
//

import SwiftUI

struct SignInEmailView: View {
    @Environment(UserSession.self) var userSession
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel = SignInEmailViewModel()

    @State private var showForgotPassword = false
    @State private var showSignUp = false
    @State private var showError = false

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
                        .frame(height: AppTheme.Spacing.xl)

                    // Header
                    AuthHeader(
                        title: "Sign In",
                        subtitle: "Welcome back! Enter your credentials"
                    )

                    Spacer()
                        .frame(height: AppTheme.Spacing.md)

                    // Form fields
                    VStack(spacing: AppTheme.Spacing.md) {
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

                            if let error = viewModel.emailError {
                                ValidationMessage(message: error, type: .error)
                            }
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text("Password")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(.secondary)

                            AuthSecureField(
                                text: $viewModel.password,
                                placeholder: "Enter your password"
                            )

                            if let error = viewModel.passwordError {
                                ValidationMessage(message: error, type: .error)
                            }
                        }

                        // Forgot password link
                        HStack {
                            Spacer()
                            Button(action: { showForgotPassword = true }) {
                                Text("Forgot password?")
                                    .font(AppTheme.Typography.caption)
                                    .foregroundColor(AppTheme.Colors.accent)
                            }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    // Sign in button
                    AuthButton(
                        title: "Sign In",
                        action: { signIn() },
                        style: .primary,
                        isEnabled: viewModel.isFormValid,
                        isLoading: viewModel.isLoading
                    )
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    Spacer()

                    // Sign up link
                    AuthLinkButton(
                        text: "Don't have an account?",
                        actionText: "Sign up",
                        action: { showSignUp = true }
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
        .navigationDestination(isPresented: $showForgotPassword) {
            ForgotPasswordView(initialEmail: viewModel.email)
                .environmentObject(themeManager)
        }
        .navigationDestination(isPresented: $showSignUp) {
            SignUpView()
                .environment(userSession)
                .environmentObject(themeManager)
        }
        .alert("Sign In Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }

    private func signIn() {
        Task {
            do {
                try await viewModel.signIn(userSession: userSession)
            } catch {
                showError = true
            }
        }
    }
}

// MARK: - Sign In Email View Model

@MainActor
class SignInEmailViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var emailError: String?
    @Published var passwordError: String?

    var isFormValid: Bool {
        ValidationUtils.isValidEmail(email) && ValidationUtils.isValidPassword(password)
    }

    init() {
        // Set up validation observers
        setupValidation()
    }

    private func setupValidation() {
        // Email validation is triggered on changes
    }

    func validateEmail() {
        if email.isEmpty {
            emailError = nil
        } else {
            emailError = ValidationUtils.emailValidationMessage(email)
        }
    }

    func validatePassword() {
        if password.isEmpty {
            passwordError = nil
        } else {
            passwordError = ValidationUtils.passwordValidationMessage(password)
        }
    }

    func signIn(userSession: UserSession) async throws {
        // Validate form
        validateEmail()
        validatePassword()

        guard isFormValid else {
            throw AuthError(type: .invalidForm)
        }

        isLoading = true
        errorMessage = nil

        do {
            try await userSession.signIn(email: email.trimmed, password: password)
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
        SignInEmailView()
            .environment(UserSession.shared)
            .environmentObject(ThemeManager.shared)
    }
}
