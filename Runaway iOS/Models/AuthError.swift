//
//  AuthError.swift
//  Runaway iOS
//
//  Comprehensive authentication error handling
//

import Foundation

/// Authentication-specific errors with localized descriptions
struct AuthError: LocalizedError {
    enum ErrorType: Equatable {
        // Credential errors
        case invalidCredentials
        case userNotFound
        case wrongPassword
        case emailAlreadyInUse
        case weakPassword
        case invalidEmail

        // Form validation errors
        case invalidForm
        case passwordsDoNotMatch
        case emptyEmail
        case emptyPassword

        // Session errors
        case noCurrentUser
        case sessionExpired
        case tokenRefreshFailed

        // Network errors
        case networkError
        case serverError
        case serviceUnavailable
        case timeout

        // Sign in with Apple errors
        case appleSignInCanceled
        case appleSignInFailed(description: String)
        case appleSignInNotAvailable

        // OAuth errors
        case oauthError(description: String)
        case unauthorized
        case forbidden

        // Password reset errors
        case passwordResetFailed
        case invalidResetCode

        // Account errors
        case accountDisabled
        case accountDeleted

        // Generic
        case unknown
        case custom(description: String)

        static func == (lhs: ErrorType, rhs: ErrorType) -> Bool {
            switch (lhs, rhs) {
            case (.invalidCredentials, .invalidCredentials),
                 (.userNotFound, .userNotFound),
                 (.wrongPassword, .wrongPassword),
                 (.emailAlreadyInUse, .emailAlreadyInUse),
                 (.weakPassword, .weakPassword),
                 (.invalidEmail, .invalidEmail),
                 (.invalidForm, .invalidForm),
                 (.passwordsDoNotMatch, .passwordsDoNotMatch),
                 (.emptyEmail, .emptyEmail),
                 (.emptyPassword, .emptyPassword),
                 (.noCurrentUser, .noCurrentUser),
                 (.sessionExpired, .sessionExpired),
                 (.tokenRefreshFailed, .tokenRefreshFailed),
                 (.networkError, .networkError),
                 (.serverError, .serverError),
                 (.serviceUnavailable, .serviceUnavailable),
                 (.timeout, .timeout),
                 (.appleSignInCanceled, .appleSignInCanceled),
                 (.appleSignInNotAvailable, .appleSignInNotAvailable),
                 (.unauthorized, .unauthorized),
                 (.forbidden, .forbidden),
                 (.passwordResetFailed, .passwordResetFailed),
                 (.invalidResetCode, .invalidResetCode),
                 (.accountDisabled, .accountDisabled),
                 (.accountDeleted, .accountDeleted),
                 (.unknown, .unknown):
                return true
            case let (.appleSignInFailed(lhsDesc), .appleSignInFailed(rhsDesc)):
                return lhsDesc == rhsDesc
            case let (.oauthError(lhsDesc), .oauthError(rhsDesc)):
                return lhsDesc == rhsDesc
            case let (.custom(lhsDesc), .custom(rhsDesc)):
                return lhsDesc == rhsDesc
            default:
                return false
            }
        }
    }

    let type: ErrorType
    let underlyingError: Error?

    init(type: ErrorType, underlyingError: Error? = nil) {
        self.type = type
        self.underlyingError = underlyingError
    }

    var errorDescription: String? {
        switch type {
        // Credential errors
        case .invalidCredentials:
            return "Invalid email or password. Please try again."
        case .userNotFound:
            return "No account found with this email address."
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .emailAlreadyInUse:
            return "An account with this email already exists."
        case .weakPassword:
            return "Password is too weak. Please use at least 8 characters."
        case .invalidEmail:
            return "Please enter a valid email address."

        // Form validation errors
        case .invalidForm:
            return "Please fill in all required fields correctly."
        case .passwordsDoNotMatch:
            return "Passwords do not match."
        case .emptyEmail:
            return "Please enter your email address."
        case .emptyPassword:
            return "Please enter your password."

        // Session errors
        case .noCurrentUser:
            return "No user is currently signed in."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .tokenRefreshFailed:
            return "Failed to refresh your session. Please sign in again."

        // Network errors
        case .networkError:
            return "Network error. Please check your connection and try again."
        case .serverError:
            return "Server error. Please try again later."
        case .serviceUnavailable:
            return "Service is temporarily unavailable. Please try again later."
        case .timeout:
            return "Request timed out. Please try again."

        // Sign in with Apple errors
        case .appleSignInCanceled:
            return "Sign in with Apple was canceled."
        case .appleSignInFailed(let description):
            return "Sign in with Apple failed: \(description)"
        case .appleSignInNotAvailable:
            return "Sign in with Apple is not available on this device."

        // OAuth errors
        case .oauthError(let description):
            return "Authentication error: \(description)"
        case .unauthorized:
            return "Unauthorized. Please check your credentials."
        case .forbidden:
            return "Access denied. You don't have permission for this action."

        // Password reset errors
        case .passwordResetFailed:
            return "Failed to send password reset email. Please try again."
        case .invalidResetCode:
            return "Invalid or expired reset code. Please request a new one."

        // Account errors
        case .accountDisabled:
            return "This account has been disabled. Please contact support."
        case .accountDeleted:
            return "This account has been deleted."

        // Generic
        case .unknown:
            return "An unknown error occurred. Please try again."
        case .custom(let description):
            return description
        }
    }

    var recoverySuggestion: String? {
        switch type {
        case .networkError, .timeout:
            return "Check your internet connection and try again."
        case .sessionExpired, .tokenRefreshFailed:
            return "Please sign in again to continue."
        case .weakPassword:
            return "Use a mix of letters, numbers, and symbols."
        case .emailAlreadyInUse:
            return "Try signing in instead, or use a different email."
        case .userNotFound:
            return "Check your email or create a new account."
        default:
            return nil
        }
    }

    /// Creates an AuthError from a generic Error
    static func from(_ error: Error) -> AuthError {
        // Check if it's already an AuthError
        if let authError = error as? AuthError {
            return authError
        }

        // Check for common error patterns
        let errorDescription = error.localizedDescription.lowercased()

        if errorDescription.contains("network") || errorDescription.contains("connection") {
            return AuthError(type: .networkError, underlyingError: error)
        }

        if errorDescription.contains("invalid") && errorDescription.contains("credential") {
            return AuthError(type: .invalidCredentials, underlyingError: error)
        }

        if errorDescription.contains("user not found") || errorDescription.contains("no user") {
            return AuthError(type: .userNotFound, underlyingError: error)
        }

        if errorDescription.contains("email") && errorDescription.contains("already") {
            return AuthError(type: .emailAlreadyInUse, underlyingError: error)
        }

        if errorDescription.contains("password") && errorDescription.contains("weak") {
            return AuthError(type: .weakPassword, underlyingError: error)
        }

        if errorDescription.contains("cancel") {
            return AuthError(type: .appleSignInCanceled, underlyingError: error)
        }

        // Default to custom error with original message
        return AuthError(type: .custom(description: error.localizedDescription), underlyingError: error)
    }
}

// MARK: - Convenience Extensions

extension AuthError {
    /// Check if error is recoverable (user can retry)
    var isRecoverable: Bool {
        switch type {
        case .networkError, .timeout, .serverError, .serviceUnavailable:
            return true
        case .appleSignInCanceled:
            return true
        default:
            return false
        }
    }

    /// Check if error requires re-authentication
    var requiresReauth: Bool {
        switch type {
        case .sessionExpired, .tokenRefreshFailed, .unauthorized:
            return true
        default:
            return false
        }
    }
}
