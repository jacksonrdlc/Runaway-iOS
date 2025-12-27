//
//  TriggerEngine.swift
//  Runaway iOS
//
//  Created by Claude on 12/23/25.
//

import Foundation
import Combine

// MARK: - Trigger Engine

/// Evaluates triggers against run state and manages prompt queue
@MainActor
final class TriggerEngine: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isRunning: Bool = false
    @Published private(set) var lastEvaluationTime: Date?
    @Published private(set) var promptsSpokenCount: Int = 0

    // MARK: - Properties

    private let registry: TriggerRegistry
    private let promptQueue: PromptQueue
    private let ttsService: TTSService

    private var evaluationTask: Task<Void, Never>?
    private var currentRunState: RunStateSnapshot?

    // Evaluation frequency
    private let evaluationInterval: TimeInterval = 1.0 // 1 Hz

    // MARK: - Callbacks

    var onPromptSpoken: ((QueuedPrompt) -> Void)?
    var onTriggerFired: ((String) -> Void)? // trigger id

    // MARK: - Initialization

    init(
        registry: TriggerRegistry = TriggerRegistry(),
        promptQueue: PromptQueue = PromptQueue(maxSize: 3),
        ttsService: TTSService = .shared
    ) {
        self.registry = registry
        self.promptQueue = promptQueue
        self.ttsService = ttsService

        setupDefaultTriggers()
    }

    // MARK: - Default Triggers

    private func setupDefaultTriggers() {
        // Phase 1: Split trigger
        registry.register(SplitTrigger())

        // Phase 2: Pace drift trigger
        registry.register(PaceDriftTrigger())

        // Phase 2: Heart rate zone triggers
        registry.register(ZoneTransitionTrigger())
        registry.register(ZoneDurationTrigger())

        // Phase 2: Check-in trigger
        registry.register(CheckInTrigger())
    }

    // MARK: - Engine Control

    /// Start the trigger evaluation loop
    func start() {
        guard !isRunning else { return }

        isRunning = true
        promptsSpokenCount = 0

        // Reset all trigger cooldowns
        registry.resetCooldowns()

        // Start evaluation loop
        evaluationTask = Task { [weak self] in
            await self?.runEvaluationLoop()
        }

        print("TriggerEngine: Started")
    }

    /// Stop the trigger evaluation loop
    func stop() {
        guard isRunning else { return }

        isRunning = false
        evaluationTask?.cancel()
        evaluationTask = nil
        promptQueue.clear()

        print("TriggerEngine: Stopped. Total prompts spoken: \(promptsSpokenCount)")
    }

    /// Pause evaluation (for auto-pause, etc.)
    func pause() {
        // Don't stop the loop, just skip evaluation when state.isPaused
    }

    /// Resume evaluation
    func resume() {
        // Loop continues, evaluation resumes automatically
    }

    // MARK: - State Updates

    /// Update the current run state (called from AudioCoachingService)
    func updateState(_ state: RunStateSnapshot) {
        currentRunState = state
    }

    // MARK: - Evaluation Loop

    private func runEvaluationLoop() async {
        while !Task.isCancelled && isRunning {
            let startTime = Date()

            // Perform evaluation
            await evaluate()

            // Calculate sleep duration to maintain 1 Hz
            let elapsed = Date().timeIntervalSince(startTime)
            let sleepDuration = max(0, evaluationInterval - elapsed)

            if sleepDuration > 0 {
                try? await Task.sleep(nanoseconds: UInt64(sleepDuration * 1_000_000_000))
            }
        }
    }

    /// Evaluate all triggers and process prompts
    private func evaluate() async {
        guard let state = currentRunState else { return }

        // Don't evaluate if paused
        guard !state.isPaused else { return }

        let now = Date()
        lastEvaluationTime = now

        // Evaluate each enabled trigger
        for trigger in registry.enabledTriggers {
            // Check cooldown first (fast check)
            guard let baseTrigger = trigger as? BaseTrigger,
                  baseTrigger.cooldownElapsed(now: now) else {
                continue
            }

            // Check if trigger should fire
            if trigger.shouldFire(state: state, now: now) {
                let prompt = trigger.generatePrompt(state: state)
                promptQueue.enqueue(prompt)
                trigger.lastFired = now

                onTriggerFired?(trigger.id)

                #if DEBUG
                print("TriggerEngine: Trigger '\(trigger.id)' fired")
                #endif
            }
        }

        // Process prompt queue if TTS is available
        await processPromptQueue()
    }

    /// Process the next prompt in the queue
    private func processPromptQueue() async {
        // Don't process if already speaking
        guard !ttsService.isSpeaking else { return }

        // Get next prompt
        guard let prompt = promptQueue.dequeue() else { return }

        // Speak the prompt
        await withCheckedContinuation { continuation in
            ttsService.speak(prompt) {
                continuation.resume()
            }
        }

        promptsSpokenCount += 1
        onPromptSpoken?(prompt)

        #if DEBUG
        print("TriggerEngine: Spoke prompt '\(prompt.type.rawValue)': \(prompt.message)")
        #endif
    }

    // MARK: - Trigger Management

    /// Enable or disable a specific trigger
    func setTriggerEnabled(_ enabled: Bool, triggerId: String) {
        registry.setEnabled(enabled, for: triggerId)
    }

    /// Get trigger by ID
    func getTrigger(id: String) -> Trigger? {
        registry.get(id: id)
    }

    /// Get all registered triggers
    var allTriggers: [Trigger] {
        registry.allTriggers
    }

    // MARK: - Manual Prompt

    /// Manually queue a prompt (for voice responses, etc.)
    func queuePrompt(_ prompt: QueuedPrompt) {
        promptQueue.enqueue(prompt)
    }

    /// Speak immediately, interrupting any current speech
    func speakImmediately(_ message: String, type: PromptType = .custom) {
        let prompt = QueuedPrompt(type: type, message: message, priority: .critical)
        ttsService.interrupt(with: prompt.message)
        promptsSpokenCount += 1
        onPromptSpoken?(prompt)
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension TriggerEngine {

    /// Simulate a state update for testing
    func simulateStateUpdate(distance: Double, pace: TimeInterval, splits: Int) {
        let state = RunStateSnapshot(
            elapsedTime: 600,
            isPaused: false,
            totalDistance: distance,
            currentPace: pace,
            averagePace: pace,
            completedSplits: splits,
            lastSplitPace: pace,
            currentSpeed: 3.0,
            distanceUnit: .miles
        )
        updateState(state)
    }

    /// Force a split trigger for testing
    func testSplitAnnouncement() {
        let state = RunStateSnapshot(
            elapsedTime: 600,
            isPaused: false,
            totalDistance: 1609.34,
            currentPace: 522,
            averagePace: 522,
            completedSplits: 1,
            lastSplitPace: 522,
            currentSpeed: 3.08,
            distanceUnit: .miles
        )

        let prompt = QueuedPrompt(
            type: .split,
            message: "Mile 1 complete. 8:42 pace.",
            priority: .medium
        )

        promptQueue.enqueue(prompt)
    }
}
#endif
