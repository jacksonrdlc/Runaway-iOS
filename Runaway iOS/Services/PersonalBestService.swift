import Foundation
import Supabase

// Fetches and refreshes personal bests by querying all activities in the DB
// (not just the in-memory subset) and upserting to athlete_personal_bests.
class PersonalBestService {
    static let shared = PersonalBestService()
    private init() {}

    // MARK: - Fetch stored PRs

    func fetchPRs(athleteId: Int) async throws -> [PersonalBest] {
        let prs: [PersonalBest] = try await supabase
            .from("athlete_personal_bests")
            .select()
            .eq("athlete_id", value: athleteId)
            .order("distance_label")
            .execute()
            .value
        return prs
    }

    // MARK: - Recompute from full activity history

    // Compares activity-level PRs and split-level PRs, upserts the faster of the two.
    func recomputeAndSave(athleteId: Int) async throws -> [PersonalBest] {
        var saved: [PersonalBest] = []

        for distance in PRDistance.allCases {
            async let activityPR = bestActivity(athleteId: athleteId, distance: distance)
            async let splitPR = bestSplitTime(athleteId: athleteId, distance: distance)

            let (activity, split) = try await (activityPR, splitPR)

            let best: PersonalBestCandidate?
            switch (activity, split) {
            case (nil, nil):       continue
            case (let a?, nil):    best = a
            case (nil, let s?):    best = s
            case (let a?, let s?): best = a.timeSeconds <= s.timeSeconds ? a : s
            }

            guard let pr = best else { continue }
            let upserted = try await upsert(pr, athleteId: athleteId)
            saved.append(upserted)
        }

        return saved
    }

    // MARK: - Private helpers

    private struct ActivityRow: Decodable {
        let id: Int
        let elapsedTime: Int?
        let startTime: Date?

        enum CodingKeys: String, CodingKey {
            case id
            case elapsedTime = "elapsed_time"
            case startTime   = "start_time"
        }
    }

    private func bestActivity(athleteId: Int, distance: PRDistance) async throws -> PersonalBestCandidate? {
        let range = distance.metersRange
        // Require at least 3:00/km pace — filters GPS-corrupted or mis-categorized activities
        let minElapsedTime = Int(range.lowerBound * 0.18)

        let rows: [ActivityRow] = try await supabase
            .from("activities")
            .select("id, elapsed_time, start_time")
            .eq("athlete_id", value: athleteId)
            .gte("distance", value: range.lowerBound)
            .lte("distance", value: range.upperBound)
            .gte("elapsed_time", value: minElapsedTime)
            .not("elapsed_time", operator: .is, value: AnyJSON.null)
            .order("elapsed_time", ascending: true)
            .limit(1)
            .execute()
            .value

        guard let best = rows.first,
              let elapsed = best.elapsedTime,
              elapsed > 0 else { return nil }

        return PersonalBestCandidate(
            distanceLabel: distance.label,
            distanceMeters: distance.nominalMeters,
            timeSeconds: elapsed,
            activityId: best.id,
            achievedAt: best.startTime ?? Date()
        )
    }

    private struct SplitPRRow: Decodable {
        let activityId: Int
        let elapsedSeconds: Int
        let achievedAt: Date

        enum CodingKeys: String, CodingKey {
            case activityId     = "activity_id"
            case elapsedSeconds = "elapsed_seconds"
            case achievedAt     = "achieved_at"
        }
    }

    private struct SplitPRParams: Encodable {
        let p_athlete_id: Int
        let p_window_splits: Int
        let p_min_dist: Double
        let p_max_dist: Double
    }

    private func bestSplitTime(athleteId: Int, distance: PRDistance) async throws -> PersonalBestCandidate? {
        if distance == .mile {
            return try await bestMileFromSplits(athleteId: athleteId)
        }
        guard let windowSize = distance.splitWindowSize else { return nil }
        let range = distance.metersRange

        let rows: [SplitPRRow] = try await supabase
            .rpc("best_split_pr", params: SplitPRParams(
                p_athlete_id: athleteId,
                p_window_splits: windowSize,
                p_min_dist: range.lowerBound,
                p_max_dist: range.upperBound
            ))
            .execute()
            .value

        guard let best = rows.first else { return nil }

        return PersonalBestCandidate(
            distanceLabel: distance.label,
            distanceMeters: distance.nominalMeters,
            timeSeconds: best.elapsedSeconds,
            activityId: best.activityId,
            achievedAt: best.achievedAt
        )
    }

    // Finds the fastest 1km split and scales to mile (1609m).
    // 1km splits don't align to exactly 1 mile, so we use pace from the best km.
    private func bestMileFromSplits(athleteId: Int) async throws -> PersonalBestCandidate? {
        let rows: [SplitPRRow] = try await supabase
            .rpc("best_split_pr", params: SplitPRParams(
                p_athlete_id: athleteId,
                p_window_splits: 1,
                p_min_dist: 900,
                p_max_dist: 1100
            ))
            .execute()
            .value

        guard let best = rows.first else { return nil }

        let mileSeconds = Int(Double(best.elapsedSeconds) * 1609.34 / 1000.0)
        return PersonalBestCandidate(
            distanceLabel: PRDistance.mile.label,
            distanceMeters: PRDistance.mile.nominalMeters,
            timeSeconds: mileSeconds,
            activityId: best.activityId,
            achievedAt: best.achievedAt
        )
    }

    private func upsert(_ candidate: PersonalBestCandidate, athleteId: Int) async throws -> PersonalBest {
        let payload = PersonalBestUpsertPayload(candidate: candidate, athleteId: athleteId)

        let result: [PersonalBest] = try await supabase
            .from("athlete_personal_bests")
            .upsert(payload, onConflict: "athlete_id,distance_label")
            .select()
            .execute()
            .value

        guard let saved = result.first else {
            throw PersonalBestServiceError.missingServerGeneratedRecord
        }
        return saved
    }
}

struct PersonalBestCandidate {
    let distanceLabel: String
    let distanceMeters: Double
    let timeSeconds: Int
    let activityId: Int?
    let achievedAt: Date
}

struct PersonalBestUpsertPayload: Encodable {
    let athlete_id: Int
    let distance_label: String
    let distance_meters: Double
    let time_seconds: Int
    let activity_id: Int?
    let achieved_at: Date
    let updated_at: Date

    init(candidate: PersonalBestCandidate, athleteId: Int, updatedAt: Date = Date()) {
        self.athlete_id = athleteId
        self.distance_label = candidate.distanceLabel
        self.distance_meters = candidate.distanceMeters
        self.time_seconds = candidate.timeSeconds
        self.activity_id = candidate.activityId
        self.achieved_at = candidate.achievedAt
        self.updated_at = updatedAt
    }
}

private enum PersonalBestServiceError: Error {
    case missingServerGeneratedRecord
}
