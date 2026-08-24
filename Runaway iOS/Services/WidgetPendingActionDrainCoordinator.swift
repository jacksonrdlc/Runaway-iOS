import Foundation

enum WidgetCommitmentPendingDecision: Equatable {
    case retainPending
    case create
    case update

    static func decide(from result: CommitmentLoadResult) -> Self {
        switch result {
        case .failure:
            return .retainPending
        case .success(let commitment):
            return commitment == nil ? .create : .update
        }
    }
}

@MainActor
final class WidgetPendingActionDrainCoordinator {
    static let shared = WidgetPendingActionDrainCoordinator()

    private var drainTask: Task<Void, Never>?
    private var drainRequested = false

    static func shouldDrain(previousReady: Bool, newReady: Bool) -> Bool {
        !previousReady && newReady
    }

    func requestDrain(_ operation: @escaping @MainActor () async -> Void) {
        drainRequested = true
        guard drainTask == nil else { return }

        drainTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while drainRequested {
                drainRequested = false
                await operation()
            }
            drainTask = nil
        }
    }

    func waitUntilIdle() async {
        await drainTask?.value
    }
}
