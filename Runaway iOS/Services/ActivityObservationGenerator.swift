import Foundation

@MainActor
struct ActivityObservationGenerator {
    private let model: any OnDeviceTextGenerating

    init(model: (any OnDeviceTextGenerating)? = nil) {
        self.model = model ?? FoundationModelsService.shared
    }

    func generate(activity: LocalActivity) async -> String {
        let fallback = deterministicObservation(for: activity)
        guard model.isAvailable else { return fallback }

        do {
            let response = try await model.generateResponse(
                prompt: prompt(for: activity),
                systemPrompt: "Write one grounded running observation using only the supplied activity metrics. Use no more than two short sentences. Never diagnose, invent history, compare against unavailable data, or give medical advice.",
                maxTokens: 160
            )
            let cleaned = response
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.count >= 12 ? String(cleaned.prefix(220)) : fallback
        } catch {
            return fallback
        }
    }

    private func prompt(for activity: LocalActivity) -> String {
        let metrics = formattedMetrics(for: activity)
        return """
        Activity name: \(activity.name ?? "Untitled activity")
        Activity type: \(activity.type ?? "Activity")
        Distance: \(metrics.distance)
        Duration: \(metrics.duration)
        Pace: \(metrics.pace)
        """
    }

    private func deterministicObservation(for activity: LocalActivity) -> String {
        let metrics = formattedMetrics(for: activity)
        guard metrics.hasDistanceAndTime else {
            return "This activity is recorded. Add distance and duration to unlock a more specific observation."
        }
        return "You covered \(metrics.distance) at \(metrics.pace), completing the session in \(metrics.duration)."
    }

    private func formattedMetrics(for activity: LocalActivity) -> Metrics {
        let meters = activity.distance ?? 0
        let seconds = activity.elapsed_time ?? 0
        let miles = meters * 0.000621371
        let hasMetrics = miles > 0 && seconds > 0
        let paceMinutes = hasMetrics ? (seconds / 60) / miles : 0
        let paceWholeMinutes = Int(paceMinutes)
        let paceSeconds = Int(((paceMinutes - Double(paceWholeMinutes)) * 60).rounded())
        let durationMinutes = Int(seconds) / 60
        let durationSeconds = Int(seconds) % 60

        return Metrics(
            distance: hasMetrics ? String(format: "%.1f miles", miles) : "not available",
            duration: seconds > 0 ? String(format: "%d:%02d", durationMinutes, durationSeconds) : "not available",
            pace: hasMetrics ? String(format: "%d:%02d/mi", paceWholeMinutes, paceSeconds) : "not available",
            hasDistanceAndTime: hasMetrics
        )
    }

    private struct Metrics {
        let distance: String
        let duration: String
        let pace: String
        let hasDistanceAndTime: Bool
    }
}
