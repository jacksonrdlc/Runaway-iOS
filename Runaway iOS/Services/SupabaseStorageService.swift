//
//  SupabaseStorageService.swift
//  Runaway iOS
//
//  Service for uploading and managing files in Supabase Storage
//

import Foundation
import UIKit
import Supabase

class SupabaseStorageService {
    static let shared = SupabaseStorageService()
    private let bucketName = "avatars"

    private init() {}

    /// Upload a profile photo to Supabase Storage
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: The user's UUID for unique file naming
    /// - Returns: The public URL of the uploaded image
    func uploadProfilePhoto(_ image: UIImage, userId: UUID) async throws -> URL {
        // Compress image
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw SupabaseStorageError.invalidImage
        }

        // Create unique filename: userId_timestamp.jpg
        let filename = "\(userId.uuidString)_\(Int(Date().timeIntervalSince1970)).jpg"
        let filePath = "profile-photos/\(filename)"

        // Upload to Supabase Storage
        do {
            _ = try await supabase.storage
                .from(bucketName)
                .upload(
                    path: filePath,
                    file: imageData,
                    options: FileOptions(contentType: "image/jpeg")
                )

            // Get public URL
            let publicURL = try supabase.storage
                .from(bucketName)
                .getPublicURL(path: filePath)

            return publicURL
        } catch {
            #if DEBUG
            print("❌ Error uploading profile photo: \(error)")
            #endif
            throw SupabaseStorageError.uploadFailed(error.localizedDescription)
        }
    }

    /// Delete a profile photo from Supabase Storage
    /// - Parameter url: The URL of the photo to delete
    func deleteProfilePhoto(url: URL) async throws {
        // Extract file path from URL
        guard let path = extractPathFromURL(url) else {
            throw SupabaseStorageError.invalidURL
        }

        do {
            _ = try await supabase.storage
                .from(bucketName)
                .remove(paths: [path])
        } catch {
            #if DEBUG
            print("❌ Error deleting profile photo: \(error)")
            #endif
            throw SupabaseStorageError.deleteFailed(error.localizedDescription)
        }
    }

    /// Extract the storage path from a Supabase public URL
    private func extractPathFromURL(_ url: URL) -> String? {
        // URL format: https://<project>.supabase.co/storage/v1/object/public/avatars/profile-photos/filename.jpg
        // We need: profile-photos/filename.jpg
        let components = url.pathComponents
        guard let bucketsIndex = components.firstIndex(of: "object"),
              bucketsIndex + 2 < components.count else {
            return nil
        }

        // Join remaining components after bucket name
        let pathComponents = Array(components.dropFirst(bucketsIndex + 3))
        return pathComponents.joined(separator: "/")
    }
}

// MARK: - Errors
enum SupabaseStorageError: LocalizedError {
    case invalidImage
    case invalidURL
    case uploadFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Failed to process image"
        case .invalidURL:
            return "Invalid storage URL"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        }
    }
}
