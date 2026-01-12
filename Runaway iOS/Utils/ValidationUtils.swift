//
//  ValidationUtils.swift
//  Runaway iOS
//
//  Form validation utilities for authentication
//

import Foundation

/// Validation utilities for authentication forms
enum ValidationUtils {

    // MARK: - Email Validation

    /// Validates an email address format
    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // RFC 5322 compliant email regex
        let emailFormat = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailFormat)
        return emailPredicate.evaluate(with: trimmed)
    }

    /// Returns validation message for email if invalid
    static func emailValidationMessage(_ email: String) -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return "Email is required"
        }

        if !trimmed.contains("@") {
            return "Email must contain @"
        }

        if !isValidEmail(email) {
            return "Please enter a valid email address"
        }

        return nil
    }

    // MARK: - Password Validation

    /// Validates password meets minimum requirements
    static func isValidPassword(_ password: String) -> Bool {
        password.count >= 8
    }

    /// Validates password strength (returns strength level 0-4)
    static func passwordStrength(_ password: String) -> Int {
        var strength = 0

        // Length checks
        if password.count >= 8 { strength += 1 }
        if password.count >= 12 { strength += 1 }

        // Character variety checks
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecial = password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil

        if hasUppercase && hasLowercase { strength += 1 }
        if hasNumber { strength += 1 }
        if hasSpecial { strength += 1 }

        return min(strength, 4)
    }

    /// Returns password strength description
    static func passwordStrengthDescription(_ password: String) -> String {
        let strength = passwordStrength(password)
        switch strength {
        case 0: return "Too weak"
        case 1: return "Weak"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Strong"
        default: return "Unknown"
        }
    }

    /// Returns validation message for password if invalid
    static func passwordValidationMessage(_ password: String) -> String? {
        if password.isEmpty {
            return "Password is required"
        }

        if password.count < 8 {
            return "Password must be at least 8 characters"
        }

        return nil
    }

    // MARK: - Password Match Validation

    /// Checks if two passwords match
    static func passwordsMatch(_ password: String, _ confirmPassword: String) -> Bool {
        !password.isEmpty && password == confirmPassword
    }

    /// Returns validation message if passwords don't match
    static func passwordMatchMessage(_ password: String, _ confirmPassword: String) -> String? {
        if confirmPassword.isEmpty {
            return nil // Don't show error for empty confirm password
        }

        if !passwordsMatch(password, confirmPassword) {
            return "Passwords do not match"
        }

        return nil
    }

    // MARK: - Phone Validation

    /// Validates phone number format (basic validation)
    static func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return cleaned.count >= 10 && cleaned.count <= 15
    }

    /// Formats phone number with country code
    static func formatPhoneNumber(_ number: String, countryCode: String = "1") -> String {
        let cleaned = number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return "+\(countryCode)\(cleaned)"
    }

    // MARK: - Name Validation

    /// Validates a name (non-empty after trimming)
    static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2
    }

    // MARK: - Form Validation Helpers

    /// Validates a complete sign-in form
    static func validateSignInForm(email: String, password: String) -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []

        if let emailError = emailValidationMessage(email) {
            errors.append(emailError)
        }

        if let passwordError = passwordValidationMessage(password) {
            errors.append(passwordError)
        }

        return (errors.isEmpty, errors)
    }

    /// Validates a complete sign-up form
    static func validateSignUpForm(
        email: String,
        password: String,
        confirmPassword: String
    ) -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []

        if let emailError = emailValidationMessage(email) {
            errors.append(emailError)
        }

        if let passwordError = passwordValidationMessage(password) {
            errors.append(passwordError)
        }

        if let matchError = passwordMatchMessage(password, confirmPassword) {
            errors.append(matchError)
        }

        return (errors.isEmpty, errors)
    }
}

// MARK: - String Extension for Validation

extension String {
    var isValidEmail: Bool {
        ValidationUtils.isValidEmail(self)
    }

    var isValidPassword: Bool {
        ValidationUtils.isValidPassword(self)
    }

    var passwordStrength: Int {
        ValidationUtils.passwordStrength(self)
    }

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
