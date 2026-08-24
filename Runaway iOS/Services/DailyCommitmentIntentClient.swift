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
    static let appGroupIdentifier = "group.com.jackrudelic.runawayios"

    private let defaults: UserDefaults
    private let directoryURL: URL
    private let fileManager: FileManager

    init(
        defaults: UserDefaults,
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws {
        self.defaults = defaults
        self.fileManager = fileManager
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            guard let containerURL = fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
            ) else {
                throw PendingWidgetCommitmentStoreError.appGroupUnavailable
            }
            self.directoryURL = containerURL.appendingPathComponent(
                "PendingWidgetCommitments",
                isDirectory: true
            )
        }
    }

    @discardableResult
    func enqueue(activityType: String, id: UUID = UUID()) throws -> PendingWidgetCommitmentAction {
        let action = PendingWidgetCommitmentAction(id: id, activityType: activityType)
        try write(action)
        return action
    }

    func pendingActions() throws -> [PendingWidgetCommitmentAction] {
        try migrateLegacyState()
        guard fileManager.fileExists(atPath: directoryURL.path) else { return [] }
        return try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" }
        .map { try JSONDecoder().decode(PendingWidgetCommitmentAction.self, from: Data(contentsOf: $0)) }
        .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    @discardableResult
    func deleteExact(_ processedAction: PendingWidgetCommitmentAction) throws -> Bool {
        let url = actionURL(processedAction.id)
        guard fileManager.fileExists(atPath: url.path) else { return false }
        let current = try JSONDecoder().decode(
            PendingWidgetCommitmentAction.self,
            from: Data(contentsOf: url)
        )
        guard current == processedAction else { return false }
        try fileManager.removeItem(at: url)
        return true
    }

    private func migrateLegacyState() throws {
        if let data = defaults.data(forKey: DailyCommitmentIntentKeys.pendingAction),
           let action = try? JSONDecoder().decode(PendingWidgetCommitmentAction.self, from: data) {
            try write(action)
            defaults.removeObject(forKey: DailyCommitmentIntentKeys.pendingAction)
        }

        if let legacyType = defaults.string(forKey: DailyCommitmentIntentKeys.pendingActivityType) {
            try write(PendingWidgetCommitmentAction(activityType: legacyType))
            defaults.removeObject(forKey: DailyCommitmentIntentKeys.pendingActivityType)
        }
    }

    private func write(_ action: PendingWidgetCommitmentAction) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let url = actionURL(action.id)
        if fileManager.fileExists(atPath: url.path) {
            let existing = try JSONDecoder().decode(
                PendingWidgetCommitmentAction.self,
                from: Data(contentsOf: url)
            )
            guard existing == action else {
                throw PendingWidgetCommitmentStoreError.actionIDCollision
            }
            return
        }
        try JSONEncoder().encode(action).write(to: url, options: .atomic)
    }

    private func actionURL(_ id: UUID) -> URL {
        directoryURL.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }
}

enum PendingWidgetCommitmentStoreError: Error {
    case appGroupUnavailable
    case actionIDCollision
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
    private let pendingStore: PendingWidgetCommitmentStore?

    init(
        defaults: UserDefaults,
        session: URLSession = .shared,
        accessToken: @escaping () async -> String?,
        now: @escaping () -> Date = Date.init,
        pendingDirectoryURL: URL? = nil
    ) {
        self.defaults = defaults
        self.session = session
        self.accessToken = accessToken
        self.now = now
        self.pendingStore = try? PendingWidgetCommitmentStore(
            defaults: defaults,
            directoryURL: pendingDirectoryURL
        )
    }

    func setCommitment(activityType: String) async -> DailyCommitmentIntentOutcome {
        guard let pendingStore,
              let pendingAction = try? pendingStore.enqueue(activityType: activityType) else {
            return .failed(nil)
        }

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
            _ = try? pendingStore.deleteExact(pendingAction)
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
