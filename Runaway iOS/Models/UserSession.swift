import SwiftUI
import Foundation
import Supabase
import WidgetKit
import Observation

/// Unified user session manager combining authentication and profile management
@MainActor
@Observable
public final class UserSession {
    // MARK: - Observable Properties

    /// Authentication state
    public var isAuthenticated = false

    /// Checking authentication state (for initial load)
    public var isCheckingAuth = true

    /// Supabase authentication user
    public var currentUser: Supabase.User?

    /// User profile from custom User model
    public var profileUser: User?

    /// Onboarding completion state
    public var hasCompletedOnboarding = true

    /// Loading onboarding state
    public var isCheckingOnboarding = false

    /// Flag to prevent re-checking onboarding after user completes it in this session
    private var onboardingCompletedInSession = false

    /// Stored athlete ID from ensureAthleteExists (used before profile is loaded)
    private var storedAthleteId: Int?

    // MARK: - Singleton

    public static let shared = UserSession()

    // MARK: - Computed Properties

    /// Convenience accessor for user ID from profile or stored athlete ID
    public var userId: Int? {
        return profileUser?.userId ?? storedAthleteId
    }

    /// User's email from authentication
    public var email: String? {
        return currentUser?.email
    }

    // MARK: - Initialization

    private init() {
        print("UserSession initialized")
        Task {
            await checkAuthState()
            await listenForAuthChanges()
        }
    }

    // MARK: - Authentication State Management

    private func checkAuthState() async {
        do {
            let session = try await supabase.auth.session
            print("✅ Found existing session for user: \(session.user.email ?? "unknown")")
            await updateAuthState(with: session.user)
        } catch {
            print("⚠️ No existing session found: \(error.localizedDescription)")
            await MainActor.run {
                self.isAuthenticated = false
            }
        }

        // Mark auth check as complete
        await MainActor.run {
            self.isCheckingAuth = false
        }
    }

    private func listenForAuthChanges() async {
        for await (event, session) in supabase.auth.authStateChanges {
            await handleAuthStateChange(event: event, session: session)
        }
    }

    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .signedIn:
            if let user = session?.user {
                await updateAuthState(with: user)
            }
        case .signedOut:
            await clearSession()
            // Refresh widgets after sign out
            WidgetRefreshService.refreshForAuthUpdate()
        case .tokenRefreshed:
            if let user = session?.user {
                await updateAuthState(with: user)
            }
        default:
            break
        }
    }

    private func updateAuthState(with user: Supabase.User) async {
        print("🔐 UserSession: Updating auth state for user \(user.email ?? "unknown")")

        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
            self.isCheckingOnboarding = true // Start checking onboarding
        }

        print("🔐 UserSession: isAuthenticated=true, isCheckingOnboarding=true")

        // Refresh widgets after authentication state update
        WidgetRefreshService.refreshForAuthUpdate()

        // Ensure athlete record exists and get the athlete ID
        let athleteId = await ensureAthleteRecordExists(for: user)
        print("🔐 UserSession: Got athlete ID: \(athleteId?.description ?? "nil")")

        // Store the athlete ID so it's available before profile is loaded
        await MainActor.run {
            self.storedAthleteId = athleteId
        }

        // Write credentials to App Group so widget can make direct Supabase calls
        if let athleteId = athleteId {
            writeWidgetCredentials(athleteId: athleteId)
        }

        // Check onboarding status using the athlete ID
        if let athleteId = athleteId {
            await checkOnboardingStatusForAthlete(athleteId: athleteId)
        } else {
            // No athlete ID - default to showing onboarding for new users
            print("🔐 UserSession: No athlete ID, defaulting to onboarding not completed")
            await MainActor.run {
                self.hasCompletedOnboarding = false
                self.isCheckingOnboarding = false
            }
        }

        print("🔐 UserSession: Final state - hasCompletedOnboarding=\(hasCompletedOnboarding), isCheckingOnboarding=\(isCheckingOnboarding)")
    }

    /// Ensures athlete record exists for the authenticated user
    /// Returns the athlete ID if successful
    private func ensureAthleteRecordExists(for user: Supabase.User) async -> Int? {
        do {
            let athleteId = try await AthleteService.ensureAthleteExists(
                authId: user.id,
                email: user.email
            )
            print("✅ UserSession: Athlete record confirmed with ID \(athleteId)")
            return athleteId
        } catch {
            print("⚠️ UserSession: Failed to ensure athlete exists: \(error)")
            return nil
        }
    }

    /// Check onboarding status for a specific athlete ID
    private func checkOnboardingStatusForAthlete(athleteId: Int) async {
        print("🔍 UserSession: Checking onboarding status for athlete \(athleteId)")

        // Skip if user just completed onboarding in this session
        if onboardingCompletedInSession {
            print("✅ UserSession: Skipping onboarding check - completed in this session")
            await MainActor.run {
                self.hasCompletedOnboarding = true
                self.isCheckingOnboarding = false
            }
            return
        }

        do {
            let isCompleted = try await OnboardingService.checkOnboardingStatus(athleteId: athleteId)
            print("✅ UserSession: OnboardingService returned isCompleted=\(isCompleted)")
            await MainActor.run {
                self.hasCompletedOnboarding = isCompleted
                self.isCheckingOnboarding = false
                self.hasCheckedOnboarding = true
                if isCompleted {
                    self.onboardingCompletedInSession = true
                }
            }
            print("✅ UserSession: Set hasCompletedOnboarding=\(isCompleted)")
        } catch {
            print("⚠️ UserSession: Failed to check onboarding status: \(error)")
            print("⚠️ UserSession: Defaulting to hasCompletedOnboarding=false (show onboarding)")
            await MainActor.run {
                // Default to NOT completed for new users - show onboarding
                self.hasCompletedOnboarding = false
                self.isCheckingOnboarding = false
            }
        }
    }

    // MARK: - Onboarding State Management

    /// Track if we've already checked onboarding status
    private var hasCheckedOnboarding = false

    /// Check if the current user has completed onboarding (called from setProfile)
    private func checkOnboardingStatus() async {
        // Skip if user just completed onboarding in this session
        if onboardingCompletedInSession {
            print("✅ UserSession: Skipping onboarding check - completed in this session")
            return
        }

        // Skip if we've already checked (prevents repeated checks from setProfile calls)
        if hasCheckedOnboarding {
            print("✅ UserSession: Skipping onboarding check - already checked")
            return
        }

        guard let athleteId = userId else {
            // No athlete ID yet - default to showing onboarding for new users
            print("⚠️ UserSession: No athlete ID for onboarding check, defaulting to not completed")
            await MainActor.run {
                self.hasCompletedOnboarding = false
            }
            return
        }

        await checkOnboardingStatusForAthlete(athleteId: athleteId)
    }

    /// Mark onboarding as completed (call after user finishes onboarding flow)
    public func markOnboardingCompleted() {
        self.onboardingCompletedInSession = true
        self.hasCompletedOnboarding = true
        self.isCheckingOnboarding = false
    }

    /// Refresh onboarding status (call when profile is set)
    public func refreshOnboardingStatus() async {
        await checkOnboardingStatus()
    }

    // MARK: - Profile Management

    /// Set the user profile
    public func setProfile(_ user: User) {
        self.profileUser = user

        // Check onboarding status now that we have the athlete ID
        Task {
            await checkOnboardingStatus()
        }
    }

    // MARK: - Widget Credential Sharing

    /// Write Supabase credentials and athlete ID to the App Group so the widget
    /// can make direct REST calls (e.g. SetDailyCommitmentIntent).
    private func writeWidgetCredentials(athleteId: Int) {
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroup.identifier) else { return }
        defaults.set(athleteId, forKey: AppConstants.WidgetKeys.athleteId)
        if let url = SupabaseConfiguration.supabaseURL {
            defaults.set(url, forKey: AppConstants.WidgetKeys.supabaseURL)
        }
        if let key = SupabaseConfiguration.supabaseKey {
            defaults.set(key, forKey: AppConstants.WidgetKeys.supabaseKey)
        }
    }

    /// Clear both auth and profile data
    private func clearSession() async {
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
            self.profileUser = nil
            self.storedAthleteId = nil // Clear stored athlete ID
            self.hasCompletedOnboarding = true // Reset to default
            self.isCheckingOnboarding = false
            self.hasCheckedOnboarding = false // Reset so next login checks fresh
            self.onboardingCompletedInSession = false
        }
    }

    // MARK: - Authentication Methods

    func signUp(email: String, password: String) async throws {
        _ = try await supabase.auth.signUp(
            email: email,
            password: password
        )
        // Auth state will be updated automatically via listener
    }

    func signIn(email: String, password: String) async throws {
        _ = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        // Auth state will be updated automatically via listener
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        await clearSession()
    }

    /// Sign in with Apple using ID token
    func signInWithApple(idToken: String, nonce: String) async throws {
        _ = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        // Auth state will be updated automatically via listener
    }

    /// Resend verification email
    func resendVerificationEmail(email: String) async throws {
        try await supabase.auth.resend(email: email, type: .signup)
    }
}
