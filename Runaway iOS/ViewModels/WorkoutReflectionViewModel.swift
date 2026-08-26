import Combine
import Foundation

enum ReflectionBodyChoice: String, CaseIterable, Identifiable, Equatable {
    case good
    case tight
    case sore

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var domainValue: ReflectionBodyState { ReflectionBodyState(rawValue: rawValue)! }

    var symbol: String {
        switch self {
        case .good: return "figure.run"
        case .tight: return "figure.cooldown"
        case .sore: return "waveform.path.ecg"
        }
    }
}

enum ReflectionMoodChoice: String, CaseIterable, Identifiable, Equatable {
    case proud
    case steady
    case drained

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var domainValue: ReflectionMood {
        switch self {
        case .proud: return .better
        case .steady: return .same
        case .drained: return .lower
        }
    }

    var symbol: String {
        switch self {
        case .proud: return "sparkles"
        case .steady: return "equal.circle"
        case .drained: return "battery.25percent"
        }
    }
}

enum ReflectionConditionChoice: String, CaseIterable, Identifiable, Hashable {
    case heat
    case hills
    case wind
    case poorSleep = "poor_sleep"
    case stress

    var id: String { rawValue }
    var label: String { rawValue.replacingOccurrences(of: "_", with: " ").capitalized }
    var domainValue: ReflectionCondition { ReflectionCondition(rawValue: rawValue)! }
}

struct WorkoutReflectionFormSnapshot: Equatable {
    let effort: Int
    let bodyStatus: ReflectionBodyChoice
    let mood: ReflectionMoodChoice
    let conditions: [ReflectionConditionChoice]
    let note: String?
}

@MainActor
final class WorkoutReflectionViewModel: ObservableObject {
    static let noteLimit = 1_000

    @Published var effort: Double = 5
    @Published var bodyStatus: ReflectionBodyChoice?
    @Published var mood: ReflectionMoodChoice?
    @Published private(set) var selectedConditions: Set<ReflectionConditionChoice> = []
    @Published var note = "" {
        didSet {
            if note.count > Self.noteLimit {
                note = String(note.prefix(Self.noteLimit))
            }
        }
    }

    var canSubmit: Bool {
        bodyStatus != nil && mood != nil
    }

    var noteCharactersRemaining: Int {
        max(0, Self.noteLimit - note.count)
    }

    func toggleCondition(_ condition: ReflectionConditionChoice) {
        if selectedConditions.contains(condition) {
            selectedConditions.remove(condition)
        } else {
            selectedConditions.insert(condition)
        }
    }

    func snapshot() -> WorkoutReflectionFormSnapshot? {
        guard let bodyStatus, let mood else { return nil }
        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        return WorkoutReflectionFormSnapshot(
            effort: min(10, max(1, Int(effort.rounded()))),
            bodyStatus: bodyStatus,
            mood: mood,
            conditions: ReflectionConditionChoice.allCases.filter(selectedConditions.contains),
            note: cleanedNote.isEmpty ? nil : cleanedNote
        )
    }
}
