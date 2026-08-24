import Foundation

enum DailyCommitmentIntentKeys {
    static let pendingActivityType = "pending_widget_commitment_type"
}

enum DailyCommitmentIntentOutcome: Equatable {
    case saved
    case requiresAuthenticatedApp
    case failed(Int?)
}

struct DailyCommitmentIntentClient {
    private let defaults: UserDefaults
    private let session: URLSession
    private let accessToken: () async -> String?
    private let now: () -> Date

    init(
        defaults: UserDefaults,
        session: URLSession = .shared,
        accessToken: @escaping () async -> String?,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.session = session
        self.accessToken = accessToken
        self.now = now
    }

    func setCommitment(activityType: String) async -> DailyCommitmentIntentOutcome {
        defaults.set(activityType, forKey: DailyCommitmentIntentKeys.pendingActivityType)

        guard let token = await accessToken(), !token.isEmpty else {
            return .requiresAuthenticatedApp
        }
        guard
            let baseURLString = defaults.string(forKey: "widget_supabase_url"),
            let baseURL = URL(string: baseURLString),
            let apiKey = defaults.string(forKey: "widget_supabase_key"),
            !apiKey.isEmpty,
            let athleteId = defaults.object(forKey: "widget_athlete_id") as? Int,
            athleteId > 0
        else {
            return .failed(nil)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let body = MutationBody(
            athleteId: athleteId,
            activityType: activityType,
            commitmentDate: dateFormatter.string(from: now())
        )

        var request = URLRequest(url: baseURL.appending(path: "rest/v1/daily_commitments"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failed(nil)
            }
            guard 200...299 ~= httpResponse.statusCode else {
                return .failed(httpResponse.statusCode)
            }

            defaults.set(activityType, forKey: "todays_commitment_type")
            defaults.set(false, forKey: "todays_commitment_fulfilled")
            defaults.removeObject(forKey: DailyCommitmentIntentKeys.pendingActivityType)
            return .saved
        } catch {
            return .failed(nil)
        }
    }
}

private struct MutationBody: Encodable {
    let athleteId: Int
    let activityType: String
    let commitmentDate: String
    let isFulfilled = false
    let commitmentLevel = "standard"

    enum CodingKeys: String, CodingKey {
        case athleteId = "athlete_id"
        case activityType = "activity_type"
        case commitmentDate = "commitment_date"
        case isFulfilled = "is_fulfilled"
        case commitmentLevel = "commitment_level"
    }
}
