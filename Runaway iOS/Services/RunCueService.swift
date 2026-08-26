import Foundation

struct RunCueService {
    static func fetchCues(
        athleteId: Int,
        profile: MindsetProfile,
        milestones: [RunnerIdentityMilestone]
    ) async throws -> [String] {
        _ = athleteId
        return await RunCueGenerator().generate(profile: profile, milestones: milestones)
    }
}
