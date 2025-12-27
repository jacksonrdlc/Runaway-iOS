//
//  QueuedPrompt.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation

// MARK: - Prompt Priority

enum PromptPriority: Int, Comparable, CaseIterable {
    case low = 1        // Landmarks, trivia
    case medium = 2     // Splits, zone changes
    case high = 3       // Pace drift alerts, check-ins
    case critical = 4   // Safety (HR too high), navigation turns

    static func < (lhs: PromptPriority, rhs: PromptPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Prompt Type

enum PromptType: String, Codable {
    case split
    case zoneTransition
    case zoneDuration
    case paceDrift
    case checkIn
    case landmark
    case hydration
    case custom

    var defaultPriority: PromptPriority {
        switch self {
        case .split: return .medium
        case .zoneTransition: return .medium
        case .zoneDuration: return .high
        case .paceDrift: return .high
        case .checkIn: return .high
        case .landmark: return .low
        case .hydration: return .low
        case .custom: return .medium
        }
    }
}

// MARK: - Queued Prompt

/// A prompt waiting to be spoken
struct QueuedPrompt: Identifiable {

    let id: UUID
    let type: PromptType
    let priority: PromptPriority
    let message: String
    let expectsResponse: Bool
    let timestamp: Date
    let metadata: [String: Any]?

    init(
        type: PromptType,
        message: String,
        priority: PromptPriority? = nil,
        expectsResponse: Bool = false,
        metadata: [String: Any]? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.priority = priority ?? type.defaultPriority
        self.message = message
        self.expectsResponse = expectsResponse
        self.timestamp = Date()
        self.metadata = metadata
    }
}

// MARK: - Prompt Queue

/// Priority queue for prompts with max size limit
final class PromptQueue {

    private var prompts: [QueuedPrompt] = []
    private let maxSize: Int
    private let lock = NSLock()

    init(maxSize: Int = 3) {
        self.maxSize = maxSize
    }

    /// Add a prompt to the queue
    func enqueue(_ prompt: QueuedPrompt) {
        lock.lock()
        defer { lock.unlock() }

        prompts.append(prompt)

        // Sort by priority (highest first), then by timestamp (oldest first)
        prompts.sort { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.timestamp < rhs.timestamp
        }

        // Trim to max size, removing lowest priority items
        while prompts.count > maxSize {
            prompts.removeLast()
        }
    }

    /// Remove and return the highest priority prompt
    func dequeue() -> QueuedPrompt? {
        lock.lock()
        defer { lock.unlock() }

        guard !prompts.isEmpty else { return nil }
        return prompts.removeFirst()
    }

    /// Peek at the next prompt without removing
    func peek() -> QueuedPrompt? {
        lock.lock()
        defer { lock.unlock() }

        return prompts.first
    }

    /// Check if queue is empty
    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }

        return prompts.isEmpty
    }

    /// Current queue size
    var count: Int {
        lock.lock()
        defer { lock.unlock() }

        return prompts.count
    }

    /// Clear all prompts
    func clear() {
        lock.lock()
        defer { lock.unlock() }

        prompts.removeAll()
    }

    /// Remove prompts of a specific type
    func remove(type: PromptType) {
        lock.lock()
        defer { lock.unlock() }

        prompts.removeAll { $0.type == type }
    }
}
