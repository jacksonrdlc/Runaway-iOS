import Foundation

enum DailyCommitmentIntentKeys {
    static let pendingActivityType = "pending_widget_commitment_type"
    static let pendingAction = "pending_widget_commitment_action"
}

struct PendingWidgetCommitmentAction: Codable, Equatable {
    static let currentVersion = 1

    let id: UUID
    let version: Int
    let activityType: String

    init(id: UUID = UUID(), version: Int = currentVersion, activityType: String) {
        self.id = id
        self.version = version
        self.activityType = activityType
    }
}

struct PendingWidgetCommitmentStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    @discardableResult
    func enqueue(activityType: String, id: UUID = UUID()) -> PendingWidgetCommitmentAction {
        let action = PendingWidgetCommitmentAction(id: id, activityType: activityType)
        if let data = try? JSONEncoder().encode(action) {
            defaults.set(data, forKey: DailyCommitmentIntentKeys.pendingAction)
            defaults.removeObject(forKey: DailyCommitmentIntentKeys.pendingActivityType)
        }
        return action
    }

    func pendingAction() -> PendingWidgetCommitmentAction? {
        if let data = defaults.data(forKey: DailyCommitmentIntentKeys.pendingAction),
           let action = try? JSONDecoder().decode(PendingWidgetCommitmentAction.self, from: data) {
            return action
        }

        guard let legacyType = defaults.string(forKey: DailyCommitmentIntentKeys.pendingActivityType) else {
            return nil
        }
        return enqueue(activityType: legacyType)
    }

    @discardableResult
    func compareAndDelete(_ processedAction: PendingWidgetCommitmentAction) -> Bool {
        guard pendingAction() == processedAction else { return false }
        defaults.removeObject(forKey: DailyCommitmentIntentKeys.pendingAction)
        return true
    }
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
        let pendingStore = PendingWidgetCommitmentStore(defaults: defaults)
        let pendingAction = pendingStore.enqueue(activityType: activityType)

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
            _ = pendingStore.compareAndDelete(pendingAction)
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
