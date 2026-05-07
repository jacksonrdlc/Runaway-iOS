import Foundation

struct RunnerMindsetService {

    static func fetchProfile(athleteId: Int) async throws -> MindsetProfile? {
        struct Row: Decodable {
            let coreMemory: CoreMemory?
            enum CodingKeys: String, CodingKey { case coreMemory = "core_memory" }
        }
        struct CoreMemory: Decodable {
            let adlerianProfile: AdlerianProfile?
            enum CodingKeys: String, CodingKey { case adlerianProfile = "adlerian_profile" }
        }
        struct AdlerianProfile: Decodable {
            let runnerIdentity: String
            let identitySummary: String
            let whyIRun: String
            let coreValues: [String]
            enum CodingKeys: String, CodingKey {
                case runnerIdentity  = "runner_identity"
                case identitySummary = "identity_summary"
                case whyIRun         = "why_i_run"
                case coreValues      = "core_values"
            }
        }

        let rows: [Row] = try await supabase
            .from("athlete_ai_profiles")
            .select("core_memory")
            .eq("athlete_id", value: athleteId)
            .execute()
            .value

        guard let profile = rows.first?.coreMemory?.adlerianProfile else { return nil }
        return MindsetProfile(
            runnerIdentity: profile.runnerIdentity,
            identitySummary: profile.identitySummary,
            whyIRun: profile.whyIRun,
            coreValues: profile.coreValues
        )
    }

    static func saveProfile(
        athleteId: Int,
        whyIRun: String,
        coreValues: [String]
    ) async throws -> MindsetProfile {
        struct Request: Encodable {
            let athlete_id: Int
            let why_i_run: String
            let core_values: [String]
            let mode: String
        }
        struct Response: Decodable {
            let runner_identity: String
            let identity_summary: String
            let why_i_run: String
            let core_values: [String]
        }

        let response: Response = try await supabase.functions.invoke(
            "identity-profile",
            options: .init(body: Request(
                athlete_id: athleteId,
                why_i_run: whyIRun,
                core_values: coreValues,
                mode: "update"
            ))
        )

        return MindsetProfile(
            runnerIdentity: response.runner_identity,
            identitySummary: response.identity_summary,
            whyIRun: response.why_i_run,
            coreValues: response.core_values
        )
    }

    static func fetchMilestones(athleteId: Int) async throws -> [RunnerIdentityMilestone] {
        let milestones: [RunnerIdentityMilestone] = try await supabase
            .from("runner_identity_milestones")
            .select()
            .eq("athlete_id", value: athleteId)
            .order("earned", ascending: false)
            .order("created_at", ascending: true)
            .execute()
            .value
        return milestones
    }
}
