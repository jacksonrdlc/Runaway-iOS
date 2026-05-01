import Foundation
import Supabase

/// Global Supabase client instance
/// Configured via environment variables or Info.plist (see SupabaseConfiguration)
let supabase: SupabaseClient = {
    do {
        let client = try SupabaseConfiguration.createClient()
        #if DEBUG
        print("✅ Supabase client initialized successfully")
        #endif
        SupabaseConfiguration.printConfiguration()
        return client
    } catch {
        fatalError("""
            ❌ Failed to initialize Supabase client: \(error.localizedDescription)

            \(SupabaseConfiguration.setupInstructions)
            """)
    }
}()
