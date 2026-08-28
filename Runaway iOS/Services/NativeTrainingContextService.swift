import Combine
import CoreLocation
import Foundation
import HealthKit
import WeatherKit
import WorkoutKit

@MainActor
final class NativeTrainingContextService: ObservableObject {
    static let shared = NativeTrainingContextService()

    @Published private(set) var heartRateZones: AppleHeartRateZoneSnapshot?
    @Published private(set) var weather: TrainingWeatherSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?

    private let healthStore = HealthKitManager.shared.healthStore
    private let weatherService = WeatherService.shared

    private init() {}

    func refresh(at location: CLLocation?) async {
        isLoading = true
        defer { isLoading = false }

        await loadPreferredHeartRateZones()
        if let location {
            await loadWeather(at: location)
        }
    }

    func loadWeather(at location: CLLocation) async {
        do {
            let forecast = try await weatherService.weather(for: location)
            let current = forecast.currentWeather
            let nextHour = forecast.hourlyForecast.forecast.first
            weather = TrainingWeatherSnapshot(
                symbolName: current.symbolName,
                feelsLikeCelsius: current.apparentTemperature.converted(to: .celsius).value,
                humidity: current.humidity,
                windMetersPerSecond: current.wind.speed.converted(to: .metersPerSecond).value,
                precipitationChance: nextHour?.precipitationChance ?? 0,
                uvIndex: current.uvIndex.value
            )
            message = nil
        } catch {
            weather = nil
            message = "Weather is temporarily unavailable."
        }
    }

    private func loadPreferredHeartRateZones() async {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        _ = await HealthKitManager.shared.requestAuthorization()

        do {
            guard let configuration = try await healthStore.preferredWorkoutZoneConfiguration(for: heartRateType) else {
                heartRateZones = nil
                return
            }
            let bpm = HKUnit.count().unitDivided(by: .minute())
            let source: AppleTrainingZoneSource
            switch configuration.source {
            case .system: source = .system
            case .user: source = .user
            case .app: source = .app
            @unknown default: source = .system
            }
            heartRateZones = AppleHeartRateZoneSnapshot(
                source: source,
                zones: configuration.zones.map {
                    AppleHeartRateZone(
                        index: $0.index,
                        minimumBPM: $0.minimum.map { Int($0.doubleValue(for: bpm).rounded()) },
                        maximumBPM: $0.maximum.map { Int($0.doubleValue(for: bpm).rounded()) }
                    )
                }
            )
        } catch {
            heartRateZones = nil
        }
    }
}

enum WorkoutDeliveryError: LocalizedError {
    case unsupported
    case authorizationDenied
    case runningWorkoutRequired

    var errorDescription: String? {
        switch self {
        case .unsupported: return "Apple Watch workout scheduling is not available on this device."
        case .authorizationDenied: return "Allow workout scheduling to send plans to Apple Watch."
        case .runningWorkoutRequired: return "Only running sessions can be sent to Apple Watch in this version."
        }
    }
}

@MainActor
final class WorkoutDeliveryService: ObservableObject {
    static let shared = WorkoutDeliveryService()
    private let scheduler = WorkoutScheduler.shared

    private init() {}

    func schedule(_ workout: DailyWorkout) async throws {
        guard WorkoutScheduler.isSupported else { throw WorkoutDeliveryError.unsupported }
        guard workout.workoutType.isRunning else { throw WorkoutDeliveryError.runningWorkoutRequired }

        var authorizationRawValue = await Self.authorizationRawValue(for: scheduler)
        if authorizationRawValue == WorkoutScheduler.AuthorizationState.notDetermined.rawValue {
            authorizationRawValue = await Self.requestAuthorizationRawValue(for: scheduler)
        }
        guard authorizationRawValue == WorkoutScheduler.AuthorizationState.authorized.rawValue else {
            throw WorkoutDeliveryError.authorizationDenied
        }

        let goal: WorkoutGoal
        if let distance = workout.distance, distance > 0 {
            goal = .distance(distance, .miles)
        } else if let duration = workout.duration, duration > 0 {
            goal = .time(Double(duration), .minutes)
        } else {
            goal = .open
        }

        let appleWorkout = SingleGoalWorkout(
            activity: .running,
            location: .outdoor,
            goal: goal
        )
        let plan = WorkoutPlan(.goal(appleWorkout))
        let date = Calendar.current.dateComponents([.calendar, .timeZone, .year, .month, .day], from: workout.date)
        await scheduler.schedule(plan, at: date)
    }

    private nonisolated static func authorizationRawValue(for scheduler: WorkoutScheduler) async -> Int {
        await scheduler.authorizationState.rawValue
    }

    private nonisolated static func requestAuthorizationRawValue(for scheduler: WorkoutScheduler) async -> Int {
        await scheduler.requestAuthorization().rawValue
    }
}
