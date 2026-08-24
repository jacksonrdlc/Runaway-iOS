import Foundation

@MainActor
protocol ActivitySyncLocalRepository: AnyObject {
    func activity(forNumericID id: Int) async throws -> Activity
    func activity(forLocalRecordID id: UUID) throws -> Activity
    func reconcileCreateAcknowledgement(
        _ activity: Activity,
        localRecordID: UUID?,
        provisionalNumericID: Int
    ) throws
}

extension LocalActivityRepository: ActivitySyncLocalRepository {
    func activity(forNumericID id: Int) async throws -> Activity {
        try await getActivity(id: id)
    }

    func activity(forLocalRecordID id: UUID) throws -> Activity {
        guard let activity = try getActivityByLocalId(id) else {
            throw RepositoryError.notFound
        }
        return ActivityMapper.toCodable(activity)
    }

    func reconcileCreateAcknowledgement(
        _ activity: Activity,
        localRecordID: UUID?,
        provisionalNumericID: Int
    ) throws {
        try reconcileCreate(
            provisionalNumericID: provisionalNumericID,
            localRecordID: localRecordID,
            serverActivity: activity
        )
    }
}

@MainActor
final class ActivitySyncAcknowledgementStore {
    private let directoryURL: URL
    private let fileManager: FileManager

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL
        self.fileManager = fileManager
    }

    func acknowledgement(for operationID: UUID) throws -> Activity? {
        let url = acknowledgementURL(for: operationID)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(Activity.self, from: Data(contentsOf: url))
    }

    func save(_ activity: Activity, for operationID: UUID) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(activity)
            .write(to: acknowledgementURL(for: operationID), options: .atomic)
    }

    func removeAcknowledgement(for operationID: UUID) throws {
        let url = acknowledgementURL(for: operationID)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func acknowledgementURL(for operationID: UUID) -> URL {
        directoryURL.appendingPathComponent(operationID.uuidString).appendingPathExtension("json")
    }

    private static var defaultDirectoryURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return root
            .appendingPathComponent("Runaway", isDirectory: true)
            .appendingPathComponent("ActivitySyncAcknowledgements", isDirectory: true)
    }
}

@MainActor
final class ActivityCreateSyncCoordinator {
    typealias RemoteUpsert = @MainActor (Activity, UUID) async throws -> Activity

    private let localRepository: any ActivitySyncLocalRepository
    private let acknowledgementStore: ActivitySyncAcknowledgementStore
    private let remoteUpsert: RemoteUpsert

    init(
        localRepository: any ActivitySyncLocalRepository,
        acknowledgementStore: ActivitySyncAcknowledgementStore? = nil,
        remoteUpsert: @escaping RemoteUpsert
    ) {
        self.localRepository = localRepository
        self.acknowledgementStore = acknowledgementStore ?? ActivitySyncAcknowledgementStore()
        self.remoteUpsert = remoteUpsert
    }

    func sync(
        operationID: UUID,
        numericEntityID: String,
        localRecordID: UUID? = nil
    ) async throws {
        guard let activityID = Int(numericEntityID) else {
            throw SyncEngineError.invalidEntityIdentifier
        }

        if let acknowledgedActivity = try acknowledgementStore.acknowledgement(for: operationID) {
            try localRepository.reconcileCreateAcknowledgement(
                acknowledgedActivity,
                localRecordID: localRecordID,
                provisionalNumericID: activityID
            )
            try acknowledgementStore.removeAcknowledgement(for: operationID)
            return
        }

        let localActivity: Activity
        if let localRecordID {
            localActivity = try localRepository.activity(forLocalRecordID: localRecordID)
        } else {
            localActivity = try await localRepository.activity(forNumericID: activityID)
        }
        let acknowledgedActivity = try await remoteUpsert(localActivity, operationID)

        // Persist the server response before touching local state. A restart replays
        // this acknowledgement without issuing another remote create.
        try acknowledgementStore.save(acknowledgedActivity, for: operationID)
        try localRepository.reconcileCreateAcknowledgement(
            acknowledgedActivity,
            localRecordID: localRecordID,
            provisionalNumericID: activityID
        )
        try acknowledgementStore.removeAcknowledgement(for: operationID)
    }
}
