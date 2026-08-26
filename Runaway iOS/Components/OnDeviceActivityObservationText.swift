import SwiftUI

struct OnDeviceActivityObservationText: View {
    let activity: LocalActivity
    let initialObservation: String

    @State private var observation: String

    init(activity: LocalActivity, initialObservation: String) {
        self.activity = activity
        self.initialObservation = initialObservation
        _observation = State(initialValue: initialObservation)
    }

    var body: some View {
        Text(observation)
            .font(.system(size: 14, design: .rounded))
            .foregroundColor(AppTheme.Colors.DarkMode.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.opacity)
            .task(id: activity.id) {
                let generated = await ActivityObservationGenerator().generate(activity: activity)
                withAnimation(.easeOut(duration: 0.25)) {
                    observation = generated
                }
                try? await ActivityObservationRemoteService().save(
                    activityId: activity.id,
                    observation: generated
                )
            }
    }
}
