//
//  SignInView.swift
//  Runaway iOS
//
//  Main sign-in view with multiple authentication options
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(UserSession.self) var userSession
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = SignInViewModel()

    @State private var showEmailSignIn = false
    @State private var showSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var backgroundColor: Color {
        themeManager.isDarkMode
            ? AppTheme.Colors.DarkMode.background
            : AppTheme.Colors.LightMode.background
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.Spacing.xl) {
                        Spacer()
                            .frame(height: AppTheme.Spacing.xl)

                        // Header
                        AuthHeader(
                            title: "Welcome to Runaway",
                            subtitle: "Track your runs, crush your goals"
                        )

                        Spacer()
                            .frame(height: AppTheme.Spacing.lg)

                        // Auth buttons
                        VStack(spacing: AppTheme.Spacing.md) {
                            // Sign in with Apple
                            SignInWithAppleButton(viewModel: viewModel) { result in
                                handleAppleSignIn(result)
                            }
                            .frame(height: 50)
                            .cornerRadius(AppTheme.CornerRadius.medium)

                            AuthDivider(text: "or")

                            // Sign in with Email
                            AuthButton(
                                title: "Continue with Email",
                                action: { showEmailSignIn = true },
                                style: .secondary,
                                systemImage: "envelope.fill"
                            )
                        }
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
                    .frame(minHeight: UIScreen.main.bounds.height - 100)
                }
            }
            .navigationDestination(isPresented: $showEmailSignIn) {
                SignInEmailView()
                    .environment(userSession)
                    .environmentObject(themeManager)
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
                    .environment(userSession)
                    .environmentObject(themeManager)
            }
            .alert("Sign In Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            do {
                switch result {
                case .success(let authorization):
                    try await viewModel.handleAppleSignIn(authorization, userSession: userSession)
                case .failure(let error):
                    throw error
                }
            } catch let error as AuthError {
                if error.type != .appleSignInCanceled {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            } catch {
                errorMessage = AuthError.from(error).localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Sign In with Apple Button

struct SignInWithAppleButton: View {
    @ObservedObject var viewModel: SignInViewModel
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        SignInWithAppleButtonViewRepresentable(
            type: .signIn,
            style: .black,
            onRequest: { request in
                viewModel.configureAppleSignInRequest(request)
            },
            onCompletion: onCompletion
        )
    }
}

// MARK: - Sign In with Apple UIKit Wrapper

struct SignInWithAppleButtonViewRepresentable: UIViewRepresentable {
    let type: ASAuthorizationAppleIDButton.ButtonType
    let style: ASAuthorizationAppleIDButton.Style
    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: type, style: style)
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleAuthorizationAppleIDButtonPress),
            for: .touchUpInside
        )
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let parent: SignInWithAppleButtonViewRepresentable

        init(_ parent: SignInWithAppleButtonViewRepresentable) {
            self.parent = parent
        }

        @objc func handleAuthorizationAppleIDButtonPress() {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            parent.onRequest(request)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            parent.onCompletion(.success(authorization))
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            parent.onCompletion(.failure(error))
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first else {
                return UIWindow()
            }
            return window
        }
    }
}

// MARK: - Sign In View Model

@MainActor
class SignInViewModel: ObservableObject {
    @Published var isLoading = false
    private var currentNonce: String?

    func configureAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleAppleSignIn(_ authorization: ASAuthorization, userSession: UserSession) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError(type: .appleSignInFailed(description: "Invalid credential type"))
        }

        guard let nonce = currentNonce else {
            throw AuthError(type: .appleSignInFailed(description: "Invalid state: nonce not set"))
        }

        guard let identityToken = appleIDCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError(type: .appleSignInFailed(description: "Unable to fetch identity token"))
        }

        isLoading = true
        defer { isLoading = false }

        // Sign in with Supabase using Apple ID token
        try await userSession.signInWithApple(idToken: idTokenString, nonce: nonce)
    }

    // MARK: - Nonce Generation

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in charset[Int(byte) % charset.count] }
        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256Hash.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }
}

// MARK: - SHA256 Hash Helper

import CryptoKit

enum SHA256Hash {
    static func hash(data: Data) -> [UInt8] {
        let digest = SHA256.hash(data: data)
        return Array(digest)
    }
}

#Preview {
    SignInView()
        .environment(UserSession.shared)
        .environmentObject(ThemeManager.shared)
}
