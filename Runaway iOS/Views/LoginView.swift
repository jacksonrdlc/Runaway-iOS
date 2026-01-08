import SwiftUI

struct LoginView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var themeManager: ThemeManager
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var colors: (background: Color, cardBg: Color, textPrimary: Color, textSecondary: Color) {
        if themeManager.isDarkMode {
            return (
                AppTheme.Colors.DarkMode.background,
                AppTheme.Colors.DarkMode.cardBackground,
                AppTheme.Colors.DarkMode.textPrimary,
                AppTheme.Colors.DarkMode.textSecondary
            )
        } else {
            return (
                AppTheme.Colors.LightMode.background,
                AppTheme.Colors.LightMode.cardBackground,
                AppTheme.Colors.LightMode.textPrimary,
                AppTheme.Colors.LightMode.textSecondary
            )
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                colors.background.ignoresSafeArea()

                VStack(spacing: AppTheme.Spacing.lg) {
                    // Logo/Icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.Colors.accent.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: "figure.run")
                            .font(.system(size: 50))
                            .foregroundColor(AppTheme.Colors.accent)
                    }
                    .padding(.top, AppTheme.Spacing.xl)

                    Text(isSignUp ? "Create Account" : "Welcome Back")
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundColor(colors.textPrimary)
                        .padding(.bottom, AppTheme.Spacing.md)

                    // Form card
                    VStack(spacing: AppTheme.Spacing.md) {
                        // Email field
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text("Email")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(colors.textSecondary)

                            TextField("", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .padding(AppTheme.Spacing.md)
                                .background(colors.cardBg)
                                .cornerRadius(AppTheme.CornerRadius.medium)
                                .foregroundColor(colors.textPrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                        .stroke(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
                                )
                                .onAppear {
                                    email = "jackrudelic@gmail.com"
                                }
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text("Password")
                                .font(AppTheme.Typography.caption)
                                .foregroundColor(colors.textSecondary)

                            SecureField("", text: $password)
                                .padding(AppTheme.Spacing.md)
                                .background(colors.cardBg)
                                .cornerRadius(AppTheme.CornerRadius.medium)
                                .foregroundColor(colors.textPrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                                        .stroke(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
                                )
                                .onAppear {
                                    password = "password"
                                }
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    // Sign in/up button
                    Button(action: {
                        Task {
                            do {
                                if isSignUp {
                                    try await userSession.signUp(email: email, password: password)
                                } else {
                                    try await userSession.signIn(email: email, password: password)
                                }
                            } catch {
                                showError = true
                                errorMessage = error.localizedDescription
                            }
                        }
                    }) {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                            .font(AppTheme.Typography.body.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.Colors.accent)
                            .cornerRadius(AppTheme.CornerRadius.medium)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)

                    // Toggle sign up/sign in
                    Button(action: { isSignUp.toggle() }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(AppTheme.Typography.body)
                            .foregroundColor(AppTheme.Colors.accent)
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(themeManager.isDarkMode ? .dark : .light, for: .navigationBar)
            .toolbarBackground(colors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}
