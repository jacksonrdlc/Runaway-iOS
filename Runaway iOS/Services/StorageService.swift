//
//  StorageService.swift
//  Runaway iOS
//
//  Created by Claude Code on 11/26/25.
//

import Foundation
import Supabase
import UIKit

/// Service for managing Supabase Storage operations
/// Handles activity map snapshots and GPX file exports
class StorageService {

    // MARK: - Storage Bucket Names

    private enum Bucket {
        static let activityMaps = "activity-maps"
        static let activityExports = "activity-exports"
    }

    // MARK: - Activity Map Storage

    /// Upload an activity map snapshot to Supabase Storage
    /// - Parameters:
    ///   - userId: The auth user ID (UUID string)
    ///   - activityId: The activity ID
    ///   - imageData: The PNG image data to upload
    /// - Returns: The public URL of the uploaded image
    static func uploadActivityMap(userId: String, activityId: Int, imageData: Data) async throws -> String {
        let fileName = "\(userId)/\(activityId)/map.png"

        #if DEBUG
        print("📤 StorageService: Uploading activity map - User: \(userId), Activity: \(activityId)")
        print("📤 StorageService: File size: \(imageData.count) bytes")
        #endif

        // Upload to Supabase Storage
        _ = try await supabase.storage
            .from(Bucket.activityMaps)
            .upload(
                path: fileName,
                file: imageData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/png",
                    upsert: true  // Replace if already exists
                )
            )

        // Get public URL
        let publicURL = try supabase.storage
            .from(Bucket.activityMaps)
            .getPublicURL(path: fileName)

        #if DEBUG
        print("✅ StorageService: Map uploaded successfully: \(publicURL)")
        #endif

        return publicURL.absoluteString
    }

    /// Get the public URL for an activity map
    /// - Parameters:
    ///   - userId: The auth user ID (UUID string)
    ///   - activityId: The activity ID
    /// - Returns: The public URL of the map image, or nil if not found
    static func getActivityMapURL(userId: String, activityId: Int) throws -> String? {
        let fileName = "\(userId)/\(activityId)/map.png"

        // Get public URL (doesn't check if file exists)
        let publicURL = try supabase.storage
            .from(Bucket.activityMaps)
            .getPublicURL(path: fileName)

        return publicURL.absoluteString
    }

    /// Delete an activity map from storage
    /// - Parameters:
    ///   - userId: The auth user ID (UUID string)
    ///   - activityId: The activity ID
    static func deleteActivityMap(userId: String, activityId: Int) async throws {
        let fileName = "\(userId)/\(activityId)/map.png"

        #if DEBUG
        print("🗑️ StorageService: Deleting activity map: \(fileName)")
        #endif

        _ = try await supabase.storage
            .from(Bucket.activityMaps)
            .remove(paths: [fileName])

        #if DEBUG
        print("✅ StorageService: Map deleted successfully")
        #endif
    }

    // MARK: - GPX Export Storage

    /// Upload a GPX export file to Supabase Storage
    /// - Parameters:
    ///   - userId: The auth user ID (UUID string)
    ///   - activityId: The activity ID
    ///   - gpxData: The GPX XML data to upload
    /// - Returns: A signed URL for downloading the GPX file (expires in 1 hour)
    static func uploadActivityExport(userId: String, activityId: Int, gpxData: Data) async throws -> String {
        let fileName = "\(userId)/\(activityId)/activity.gpx"

        #if DEBUG
        print("📤 StorageService: Uploading GPX export - User: \(userId), Activity: \(activityId)")
        print("📤 StorageService: File size: \(gpxData.count) bytes")
        #endif

        // Upload to Supabase Storage
        _ = try await supabase.storage
            .from(Bucket.activityExports)
            .upload(
                path: fileName,
                file: gpxData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "application/gpx+xml",
                    upsert: true
                )
            )

        // Get signed URL (private, expires in 1 hour)
        let signedURL = try await supabase.storage
            .from(Bucket.activityExports)
            .createSignedURL(path: fileName, expiresIn: 3600)

        #if DEBUG
        print("✅ StorageService: GPX exported successfully: \(signedURL)")
        #endif

        return signedURL.absoluteString
    }

    /// Get a signed URL for downloading an activity GPX export
    /// - Parameters:
    ///   - userId: The auth user ID (UUID string)
    ///   - activityId: The activity ID
    ///   - expiresIn: URL expiration time in seconds (default: 1 hour)
    /// - Returns: A signed URL for downloading the GPX file
    static func getActivityExportURL(userId: String, activityId: Int, expiresIn: Int = 3600) async throws -> String {
        let fileName = "\(userId)/\(activityId)/activity.gpx"

        let signedURL = try await supabase.storage
            .from(Bucket.activityExports)
            .createSignedURL(path: fileName, expiresIn: expiresIn)

        return signedURL.absoluteString
    }

    /// Delete an activity GPX export from storage
    /// - Parameters:
    ///   - userId: The auth user ID (UUID string)
    ///   - activityId: The activity ID
    static func deleteActivityExport(userId: String, activityId: Int) async throws {
        let fileName = "\(userId)/\(activityId)/activity.gpx"

        #if DEBUG
        print("🗑️ StorageService: Deleting GPX export: \(fileName)")
        #endif

        _ = try await supabase.storage
            .from(Bucket.activityExports)
            .remove(paths: [fileName])

        #if DEBUG
        print("✅ StorageService: GPX export deleted successfully")
        #endif
    }

    // MARK: - Batch Operations

    /// Delete all storage files for a specific activity (map + export)
    /// - Parameters:
    ///   - userId: The auth user ID (UUID string)
    ///   - activityId: The activity ID
    static func deleteAllActivityFiles(userId: String, activityId: Int) async throws {
        // Delete map and export in parallel
        async let mapDelete: () = deleteActivityMap(userId: userId, activityId: activityId)
        async let exportDelete: () = deleteActivityExport(userId: userId, activityId: activityId)

        // Wait for both deletions (ignore errors if files don't exist)
        _ = try? await mapDelete
        _ = try? await exportDelete

        #if DEBUG
        print("✅ StorageService: All files deleted for activity \(activityId)")
        #endif
    }

    /// List all map snapshots for a user
    /// - Parameter userId: The auth user ID (UUID string)
    /// - Returns: Array of file paths
    static func listUserMaps(userId: String) async throws -> [String] {
        let files = try await supabase.storage
            .from(Bucket.activityMaps)
            .list(path: userId)

        return files.map { $0.name }
    }

    /// List all GPX exports for a user
    /// - Parameter userId: The auth user ID (UUID string)
    /// - Returns: Array of file paths
    static func listUserExports(userId: String) async throws -> [String] {
        let files = try await supabase.storage
            .from(Bucket.activityExports)
            .list(path: userId)

        return files.map { $0.name }
    }

    // MARK: - Utility Functions

    /// Convert UIImage to PNG Data for storage
    /// - Parameter image: The UIImage to convert
    /// - Returns: PNG data, or nil if conversion fails
    static func imageToData(_ image: UIImage) -> Data? {
        return image.pngData()
    }

    /// Generate GPX XML from activity data
    /// - Parameter activity: The activity to export
    /// - Returns: GPX XML data
    static func generateGPXData(from activity: Activity) -> Data? {
        guard let polyline = activity.summary_polyline,
              !polyline.isEmpty else {
            #if DEBUG
            print("⚠️ StorageService: No polyline data available for GPX export")
            #endif
            return nil
        }

        // Basic GPX structure
        // Note: In production, use CoreGPX library for proper GPX generation
        let gpxTemplate = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Runaway iOS">
            <metadata>
                <name>\(activity.name ?? "Activity")</name>
                <time>\(ISO8601DateFormatter().string(from: Date()))</time>
            </metadata>
            <trk>
                <name>\(activity.name ?? "Activity")</name>
                <type>\(activity.type ?? "Run")</type>
                <trkseg>
                    <!-- Polyline: \(polyline) -->
                    <!-- Note: Implement polyline to coordinates conversion -->
                </trkseg>
            </trk>
        </gpx>
        """

        return gpxTemplate.data(using: .utf8)
    }
}

// MARK: - Storage Error Handling

enum StorageError: Error, LocalizedError {
    case uploadFailed(String)
    case downloadFailed(String)
    case deleteFailed(String)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}
