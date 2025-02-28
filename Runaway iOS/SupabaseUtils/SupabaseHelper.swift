import Foundation
import Supabase

class SupabaseHelper {
    static let shared = SupabaseHelper()
    
    let client: SupabaseClient
    
    private init() {
        // Replace with your Supabase project URL and anon key
        client = SupabaseClient(
            supabaseURL: URL(string: "https://onymzwnbxsvltsxpcidy.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ueW16d25ieHN2bHRzeHBjaWR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY5NTI1MjksImV4cCI6MjA1MjUyODUyOX0.zx-iuXOjNsOEUq6IIFtOMvCBnUFqnnbwkH4f6e3DgSE"
        )
    }
}
