//
//  SupabaseDecoder.swift
//  Runaway iOS
//
//  Shared JSON decoder configured for Supabase date formats
//

import Foundation

/// Shared JSON decoder that handles Supabase's ISO 8601 date format
enum SupabaseDecoder {
    /// Decoder configured for Supabase responses with ISO 8601 dates
    static let shared: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO 8601 with fractional seconds (e.g., "2026-01-14T20:02:26.11139+00:00")
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try ISO 8601 without fractional seconds (e.g., "2026-01-14T20:02:26+00:00")
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try date-only format (e.g., "2026-01-14")
            let dateOnlyFormatter = DateFormatter()
            dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
            dateOnlyFormatter.timeZone = TimeZone(identifier: "UTC")
            if let date = dateOnlyFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string: \(dateString)"
            )
        }
        return decoder
    }()
}
