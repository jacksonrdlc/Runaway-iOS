//
//  SupabaseConfiguration.swift
//  Runaway iOS
//
//  Configuration for Supabase client with environment variable support
//

import Foundation
import Supabase

// MARK: - Simulator-only networking + auth workarounds

#if targetEnvironment(simulator)

/// Forces HTTP/2 by routing all requests through a local TCP CONNECT proxy.
/// QUIC (HTTP/3) fails in the iOS Simulator — iOS 18.4 ignores assumesHTTP3Capable=false
/// when HTTPS DNS SVCB records advertise h3. A TCP-only proxy physically prevents UDP/QUIC.
/// Registered only in Simulator builds; production uses the default URLSession stack.
private final class HTTP2ForcedURLProtocol: URLProtocol {

    private static let handledKey = "HTTP2ForcedURLProtocol.handled"

    private static let innerSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = [
            "HTTPSEnable": true,
            "HTTPSProxy": "127.0.0.1",
            "HTTPSPort": 18888,
        ]
        return URLSession(configuration: config)
    }()

    private var activeTask: URLSessionDataTask?

    override class func canInit(with request: URLRequest) -> Bool {
        URLProtocol.property(forKey: handledKey, in: request) == nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let mutable = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutable)
        var forwarded = mutable as URLRequest
        forwarded.assumesHTTP3Capable = false

        activeTask = Self.innerSession.dataTask(with: forwarded) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }
            if let response { self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed) }
            if let data { self.client?.urlProtocol(self, didLoad: data) }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        activeTask?.resume()
    }

    override func stopLoading() {
        activeTask?.cancel()
        activeTask = nil
    }
}

// MARK: - UserDefaultsAuthStorage

/// AuthLocalStorage backed by UserDefaults.
/// Keychain requires entitlements that standalone injection tools don't have in the Simulator.
/// UserDefaults lets sessions be pre-seeded via `xcrun simctl spawn … defaults write`.
struct UserDefaultsAuthStorage: AuthLocalStorage {
    private let defaults = UserDefaults.standard
    func store(key: String, value: Data) throws {
        defaults.set(value, forKey: key)
    }
    func retrieve(key: String) throws -> Data? {
        defaults.data(forKey: key)
    }
    func remove(key: String) throws {
        defaults.removeObject(forKey: key)
    }
}

#endif // targetEnvironment(simulator)

// MARK: - SupabaseConfiguration

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

    // MARK: - Auth Configuration

    /// Deep link URL scheme for auth callbacks
    static let authRedirectURL = URL(string: "runaway://auth/callback")

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

        #if targetEnvironment(simulator)
        // QUIC (HTTP/3) fails in the Simulator — route all Supabase traffic through
        // HTTP2ForcedURLProtocol, which tunnels over a local TCP CONNECT proxy.
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.protocolClasses = [HTTP2ForcedURLProtocol.self] + (URLSessionConfiguration.default.protocolClasses ?? [])
        let session = URLSession(configuration: sessionConfig)
        let authOptions = SupabaseClientOptions.AuthOptions(
            storage: UserDefaultsAuthStorage(),
            redirectToURL: authRedirectURL
        )
        #else
        let session = URLSession.shared
        let authOptions = SupabaseClientOptions.AuthOptions(redirectToURL: authRedirectURL)
        #endif

        let client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(
                auth: authOptions,
                global: SupabaseClientOptions.GlobalOptions(
                    session: session
                )
            )
        )

        #if DEBUG
        print("🔐 Supabase client configured with redirect URL: \(authRedirectURL?.absoluteString ?? "none")")
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
