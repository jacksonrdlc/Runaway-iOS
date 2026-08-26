import Foundation

@MainActor
struct RunCueGenerator {
    private let model: OnDeviceTextGenerating

    init(model: OnDeviceTextGenerating? = nil) {
        self.model = model ?? FoundationModelsService.shared
    }

    func generate(
        profile: MindsetProfile,
        milestones: [RunnerIdentityMilestone]
    ) async -> [String] {
        let fallback = deterministicCues(profile: profile, milestones: milestones)
        guard model.isAvailable else { return fallback }

        do {
            let response = try await model.generateResponse(
                prompt: prompt(profile: profile, milestones: milestones),
                systemPrompt: "Generate short, grounded running cues. Never diagnose, shame, or invent athlete facts. Return one cue per line.",
                maxTokens: 512
            )
            let cues = parse(response)
            return cues.count >= 5 ? Array(cues.prefix(12)) : fallback
        } catch {
            return fallback
        }
    }

    private func prompt(
        profile: MindsetProfile,
        milestones: [RunnerIdentityMilestone]
    ) -> String {
        let earned = milestones.filter(\.earned).map(\.label)
        return """
        Create 8 concise motivational cues for one run. Each cue should be one sentence and specific only to the supplied context.

        Runner identity: \(profile.runnerIdentity)
        Identity summary: \(profile.identitySummary)
        Why they run: \(profile.whyIRun)
        Core values: \(profile.coreValues.joined(separator: ", "))
        Earned milestones: \(earned.isEmpty ? "None supplied" : earned.joined(separator: ", "))
        """
    }

    private func parse(_ response: String) -> [String] {
        var seen = Set<String>()
        return response
            .components(separatedBy: .newlines)
            .map {
                $0.replacingOccurrences(
                    of: #"^\s*(?:[-•]|\d+[.)])\s*"#,
                    with: "",
                    options: .regularExpression
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { $0.count >= 8 && seen.insert($0).inserted }
    }

    private func deterministicCues(
        profile: MindsetProfile,
        milestones: [RunnerIdentityMilestone]
    ) -> [String] {
        let primaryValue = profile.coreValues.first ?? "patience"
        var cues = [
            "Settle in. You are here because \(profile.whyIRun).",
            "Let \(primaryValue.lowercased()) guide the effort, not the clock.",
            "Run this part with control; there is no need to prove it all at once.",
            "Your next steady step is enough right now.",
            "Stay relaxed through the shoulders and honest with the effort.",
            "You are practicing the habits of a \(profile.runnerIdentity.lowercased()).",
            "Keep the effort sustainable and leave room to finish well.",
            "Close with intention, not tension."
        ]

        if let milestone = milestones.first(where: \.earned) {
            cues.insert("You earned \(milestone.label); carry that evidence forward.", at: 4)
        }
        return cues
    }
}
