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
            let athleteId: Int
            let whyIRun: String
            let coreValues: [String]
            let mode: String
            enum CodingKeys: String, CodingKey {
                case athleteId  = "athlete_id"
                case whyIRun    = "why_i_run"
                case coreValues = "core_values"
                case mode
            }
        }
        struct Response: Decodable {
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

        let response: Response = try await supabase.functions.invoke(
            "identity-profile",
            options: .init(body: Request(
                athleteId: athleteId,
                whyIRun: whyIRun,
                coreValues: coreValues,
                mode: "update"
            ))
        )

        return MindsetProfile(
            runnerIdentity: response.runnerIdentity,
            identitySummary: response.identitySummary,
            whyIRun: response.whyIRun,
            coreValues: response.coreValues
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
