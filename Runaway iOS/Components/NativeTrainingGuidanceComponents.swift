import SwiftUI

struct NativeTrainingSummaryStrip: View {
    let workout: DailyWorkout
    @StateObject private var context = NativeTrainingContextService.shared
    @StateObject private var locationManager = LocationManager.shared

    private var target: TrainingZoneTarget? {
        NativeTrainingGuidancePolicy.zoneTarget(for: workout.workoutType)
    }

    var body: some View {
        if target != nil || context.weather != nil {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(AppTheme.Colors.success)
                if let target {
                    Text(target.label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                if let weather = context.weather {
                    Divider().frame(height: 14)
                    Image(systemName: weather.symbolName)
                    Text(weather.feelsLikeCelsius.formatted(.number.precision(.fractionLength(0))) + "°")
                }
                Spacer(minLength: 0)
                Text("Apple native")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
            }
            .font(.system(size: 12, design: .rounded))
            .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(AppTheme.Colors.success.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.small + 4))
            .task {
                locationManager.requestLocationPermission()
                locationManager.requestSingleLocation()
                await context.refresh(at: locationManager.location)
            }
            .onChange(of: locationManager.location?.timestamp) { _, _ in
                guard let location = locationManager.location else { return }
                Task { await context.loadWeather(at: location) }
            }
        }
    }
}

struct NativeWorkoutContextCard: View {
    let workout: DailyWorkout
    @StateObject private var context = NativeTrainingContextService.shared
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var readinessService = ReadinessService.shared
    @State private var isScheduling = false
    @State private var deliveryMessage: String?
    @State private var deliverySucceeded = false

    private var target: TrainingZoneTarget? {
        NativeTrainingGuidancePolicy.zoneTarget(for: workout.workoutType)
    }

    private var calibration: ReadinessCalibrationAssessment {
        let availableWeight = readinessService.todaysReadiness?.factors.reduce(0) { $0 + $1.weight } ?? 0
        return ReadinessCalibrationPolicy.assessment(
            availableWeight: availableWeight,
            hasPersonalZones: context.heartRateZones != nil
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Native training intelligence", systemImage: "applewatch.radiowaves.left.and.right")
                .font(.headline)

            if let target {
                contextRow(
                    icon: "waveform.path.ecg",
                    tint: .cyan,
                    title: target.label + " · " + target.name,
                    detail: zoneDetail(target)
                )
            }

            if let weather = context.weather {
                let guidance = NativeTrainingGuidancePolicy.weatherGuidance(for: weather, workoutType: workout.workoutType)
                contextRow(
                    icon: weather.symbolName,
                    tint: guidance.level == .high ? .orange : (guidance.level == .caution ? .yellow : .teal),
                    title: guidance.title,
                    detail: weatherLine(weather) + "\n" + guidance.detail
                )
            } else if locationManager.isLocationDenied {
                contextRow(
                    icon: "location.slash",
                    tint: .secondary,
                    title: "Weather guidance off",
                    detail: "Enable location access to calibrate outdoor conditions."
                )
            }

            contextRow(
                icon: "scope",
                tint: calibration.level == .limited ? .orange : .teal,
                title: calibration.level.rawValue + " calibration confidence",
                detail: calibration.detail
            )

            if workout.workoutType.isRunning {
                Button {
                    Task { await scheduleWorkout() }
                } label: {
                    HStack {
                        if isScheduling { ProgressView().tint(.white) }
                        else { Image(systemName: deliverySucceeded ? "checkmark" : "applewatch") }
                        Text(deliverySucceeded ? "Scheduled on Apple Watch" : "Schedule on Apple Watch")
                        Spacer()
                        if !deliverySucceeded { Image(systemName: "chevron.right") }
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(14)
                    .background(AppTheme.Colors.success)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(isScheduling || deliverySucceeded)
            }

            if let deliveryMessage {
                Text(deliveryMessage)
                    .font(.caption)
                    .foregroundColor(deliverySucceeded ? AppTheme.Colors.success : .orange)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .task {
            locationManager.requestLocationPermission()
            locationManager.requestSingleLocation()
            await context.refresh(at: locationManager.location)
        }
        .onChange(of: locationManager.location?.timestamp) { _, _ in
            guard let location = locationManager.location else { return }
            Task { await context.loadWeather(at: location) }
        }
    }

    private func contextRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(detail)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func zoneDetail(_ target: TrainingZoneTarget) -> String {
        let range = context.heartRateZones?.bpmRange(for: target)
        let source = context.heartRateZones?.source.rawValue
        return [range, source, target.detail].compactMap { $0 }.joined(separator: " · ")
    }

    private func weatherLine(_ weather: TrainingWeatherSnapshot) -> String {
        let feels = weather.feelsLikeCelsius.formatted(.number.precision(.fractionLength(0)))
        let humidity = (weather.humidity * 100).formatted(.number.precision(.fractionLength(0)))
        let wind = weather.windMetersPerSecond.formatted(.number.precision(.fractionLength(1)))
        return "Feels \(feels)°C · \(humidity)% humidity · \(wind) m/s wind"
    }

    private func scheduleWorkout() async {
        isScheduling = true
        defer { isScheduling = false }
        do {
            try await WorkoutDeliveryService.shared.schedule(workout)
            deliverySucceeded = true
            deliveryMessage = "The workout will appear in the Workout app on your paired Apple Watch."
        } catch {
            deliverySucceeded = false
            deliveryMessage = error.localizedDescription
        }
    }
}
