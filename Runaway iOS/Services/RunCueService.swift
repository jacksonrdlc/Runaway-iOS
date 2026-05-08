import Foundation

struct RunCueService {
    static func fetchCues(
        athleteId: Int,
        profile: MindsetProfile,
        milestones: [RunnerIdentityMilestone]
    ) async throws -> [String] {
        struct Request: Encodable {
            let athleteId: Int
            let runnerIdentity: String
            let whyIRun: String
            let coreValues: [String]
            let earnedMilestoneKeys: [String]
            enum CodingKeys: String, CodingKey {
                case athleteId           = "athlete_id"
                case runnerIdentity      = "runner_identity"
                case whyIRun             = "why_i_run"
                case coreValues          = "core_values"
                case earnedMilestoneKeys = "earned_milestone_keys"
            }
        }
        struct Response: Decodable {
            let cues: [String]
        }

        let earnedKeys = milestones.filter { $0.earned }.map { $0.milestoneKey }

        let response: Response = try await supabase.functions.invoke(
            "generate-run-cues",
            options: .init(body: Request(
                athleteId: athleteId,
                runnerIdentity: profile.runnerIdentity,
                whyIRun: profile.whyIRun,
                coreValues: profile.coreValues,
                earnedMilestoneKeys: earnedKeys
            ))
        )
        return response.cues
    }
}
