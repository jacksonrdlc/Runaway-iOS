//
//  SupabaseConfiguration.swift
//  Runaway iOS
//
//  Configuration for Supabase client with environment variable support
//

import Foundation
import Supabase

struct SupabaseConfiguration {

    // MARK: - Supabase Credentials

    /// Supabase Project URL
    /// Priority: Environment Variable > Info.plist > Hardcoded (nil)
    static var supabaseURL: String? {
        // 1. Check environment variable first (recommended for security)
        if let envURL = ProcessInfo.processInfo.environment["SUPABASE_URL"] {
            return envURL
        }

        // 2. Check Info.plist configuration
        if let plistURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
           !plistURL.isEmpty {
            return plistURL
        }

        // 3. Hardcoded fallback (not recommended - should be nil in production)
        return hardcodedSupabaseURL
    }

    /// Supabase Anon/Service Key
    /// Priority: Environment Variable > Info.plist > Hardcoded (nil)
    static var supabaseKey: String? {
        // 1. Check environment variable first (recommended for security)
        if let envKey = ProcessInfo.processInfo.environment["SUPABASE_KEY"] {
            return envKey
        }

        // 2. Check Info.plist configuration
        if let plistKey = Bundle.main.infoDictionary?["SUPABASE_KEY"] as? String,
           !plistKey.isEmpty {
            return plistKey
        }

        // 3. Hardcoded fallback (not recommended - should be nil in production)
        return hardcodedSupabaseKey
    }

    // MARK: - Hardcoded Credentials (NOT RECOMMENDED)
    // SECURITY: Never commit credentials to source control!
    // Use environment variables or Info.plist instead

    /// ⚠️ SECURITY WARNING: Remove these hardcoded values and use environment variables or Info.plist
    private static let hardcodedSupabaseURL: String? = nil
    private static let hardcodedSupabaseKey: String? = nil

    // MARK: - Supabase Client Factory

    /// Creates a configured Supabase client
    /// - Throws: ConfigurationError if credentials are missing
    static func createClient() throws -> SupabaseClient {
        guard let urlString = supabaseURL,
              let url = URL(string: urlString) else {
            throw ConfigurationError.missingSupabaseURL
        }

        guard let key = supabaseKey else {
            throw ConfigurationError.missingSupabaseKey
        }

        // Create client with default configuration (includes session persistence)
        let client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key
        )

        #if DEBUG
        print("🔐 Supabase client configured with session persistence enabled")
        #endif

        return client
    }

    // MARK: - Configuration Validation

    static var hasSupabaseURL: Bool {
        return supabaseURL != nil && !supabaseURL!.isEmpty
    }

    static var hasSupabaseKey: Bool {
        return supabaseKey != nil && !supabaseKey!.isEmpty
    }

    static var isConfigured: Bool {
        return hasSupabaseURL && hasSupabaseKey
    }

    static var configurationSource: String {
        var urlSource = "None"
        var keySource = "None"

        // Determine URL source
        if ProcessInfo.processInfo.environment["SUPABASE_URL"] != nil {
            urlSource = "Environment Variable"
        } else if Bundle.main.infoDictionary?["SUPABASE_URL"] as? String != nil {
            urlSource = "Info.plist"
        } else if hardcodedSupabaseURL != nil {
            urlSource = "Hardcoded (Not Recommended)"
        }

        // Determine Key source
        if ProcessInfo.processInfo.environment["SUPABASE_KEY"] != nil {
            keySource = "Environment Variable"
        } else if Bundle.main.infoDictionary?["SUPABASE_KEY"] as? String != nil {
            keySource = "Info.plist"
        } else if hardcodedSupabaseKey != nil {
            keySource = "Hardcoded (Not Recommended)"
        }

        return "URL: \(urlSource), Key: \(keySource)"
    }

    // MARK: - Debug Helpers

    static func printConfiguration() {
        print("🔧 Supabase Configuration:")
        print("   URL Configured: \(hasSupabaseURL ? "✅" : "❌")")
        print("   Key Configured: \(hasSupabaseKey ? "✅" : "❌")")
        print("   Configuration Source: \(configurationSource)")

        if let url = supabaseURL {
            // Only print the domain, not full URL for security
            let components = URLComponents(string: url)
            let domain = components?.host ?? "unknown"
            print("   Supabase Domain: \(domain)")
        }

        #if DEBUG
        print("   Build Mode: DEBUG")
        #else
        print("   Build Mode: RELEASE")
        #endif
    }

    // MARK: - Error Types

    enum ConfigurationError: LocalizedError {
        case missingSupabaseURL
        case missingSupabaseKey

        var errorDescription: String? {
            switch self {
            case .missingSupabaseURL:
                return "Supabase URL is not configured. Set SUPABASE_URL environment variable or add to Info.plist."
            case .missingSupabaseKey:
                return "Supabase Key is not configured. Set SUPABASE_KEY environment variable or add to Info.plist."
            }
        }
    }
}

// MARK: - Setup Instructions
extension SupabaseConfiguration {
    static var setupInstructions: String {
        return """
        To configure Supabase, add credentials using one of these methods:

        1. RECOMMENDED: Environment Variables
           - Set SUPABASE_URL=your-project-url
           - Set SUPABASE_KEY=your-anon-or-service-key

        2. Info.plist Configuration
           - Add SUPABASE_URL key with your Supabase project URL
           - Add SUPABASE_KEY key with your anon or service key
           - Copy from Runaway-iOS-Info.plist.template

        3. Get your credentials from Supabase Dashboard:
           - Go to https://supabase.com/dashboard
           - Select your project
           - Go to Settings > API
           - Copy Project URL and anon/service key

        ⚠️  SECURITY NOTE:
        - Use ANON key for client-side applications
        - NEVER commit service role keys to source control
        - Use environment variables in CI/CD pipelines
        - Add Runaway-iOS-Info.plist to .gitignore
        """
    }
}
