import Foundation

enum WorkoutDebriefPolicy {
    static func debrief(
        for reflection: WorkoutReflection,
        activity: WorkoutActivitySummary
    ) -> String {
        let sessionName = activity.sportType.lowercased() == "run" ? "run" : "session"
        let conditionContext = conditionSentence(for: reflection.conditionTags)

        switch reflection.bodyState {
        case .pain:
            return "Pain is a signal to stop and give your body recovery time. If it persists or concerns you, consider checking in with a qualified health professional."

        case .sore where reflection.perceivedEffort >= 8:
            return "That was a hard \(sessionName), and you finished feeling sore. Prioritize recovery and monitor how your body responds before the next hard effort."

        case .tight where reflection.perceivedEffort >= 8:
            return "That was a hard \(sessionName), and you noticed tightness. Give recovery extra attention and ease back if the tightness continues."

        case .good where reflection.perceivedEffort >= 8:
            return "You logged a demanding \(sessionName). Make recovery the priority before your next hard effort."

        case _ where reflection.mood == .lower:
            return "You showed up even though the \(sessionName) left your mood lower. Keep the next step gentle and give yourself room to recover."

        default:
            let base = reflection.mood == .better
                ? "This \(sessionName) left you feeling better, which is useful feedback to carry forward."
                : "You completed the \(sessionName) with a manageable effort."
            return conditionContext.map { "\(base) \($0)" } ?? base
        }
    }

    private static func conditionSentence(
        for conditions: [ReflectionCondition]
    ) -> String? {
        guard let first = conditions.first else { return nil }

        switch first {
        case .heat:
            return "The heat added meaningful context to that effort."
        case .hills:
            return "The hills added meaningful context to that effort."
        case .wind:
            return "The wind added meaningful context to that effort."
        case .poorSleep:
            return "Poor sleep added meaningful context to that effort."
        case .stress:
            return "Stress added meaningful context to that effort."
        }
    }
}
