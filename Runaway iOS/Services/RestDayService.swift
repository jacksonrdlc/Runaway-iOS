//
//  RestDayService.swift
//  Runaway iOS
//
//  Service for detecting and managing rest days
//  Automatically logs days without activities as rest days
//

import Foundation
import Combine

@MainActor
class RestDayService: ObservableObject {
    static let shared = RestDayService()

    // MARK: - Published Properties

    @Published private(set) var recentRestDays: [RestDay] = []
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var recoveryStatus: RecoveryStatus = .adequate
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: Error?

    // MARK: - Private Properties

    private let cacheKey = "cached_rest_days"
    private let lastDetectionKey = "last_rest_day_detection"

    // MARK: - Initialization

    private init() {
        loadCachedData()
    }

    // MARK: - Public Methods

    /// Detect and log rest days for the past N days
    /// Should be called on app launch and after activity sync
    func detectAndLogRestDays(athleteId: Int, lookbackDays: Int = 7) async throws -> Int {
        isLoading = true
        lastError = nil

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        #if DEBUG
        print("🛏️ RestDayService: Detecting rest days for last \(lookbackDays) days")
        #endif

        // Get activities for the lookback period
        let activities = try await ActivityService.getAllActivitiesByUser(
            userId: athleteId,
            limit: 100
        )

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Build a set of dates that have activities
        var activityDates: Set<Date> = []
        for activity in activities {
            guard let timestamp = activity.activity_date ?? activity.start_date else { continue }
            let activityDate = calendar.startOfDay(for: Date(timeIntervalSince1970: timestamp))
            activityDates.insert(activityDate)
        }

        // Get existing rest days to avoid duplicates
        let existingRestDays = try await getRestDays(athleteId: athleteId, days: lookbackDays)
        var existingDates = Set(existingRestDays.map { calendar.startOfDay(for: $0.date) })

        // Check each day in the lookback period (excluding today)
        var insertedCount = 0
        for dayOffset in 1...lookbackDays {
            guard let checkDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }

            let normalizedDate = calendar.startOfDay(for: checkDate)

            // Skip if there's an activity or already a rest day
            if activityDates.contains(normalizedDate) || existingDates.contains(normalizedDate) {
                continue
            }

            // Log this as a rest day
            do {
                let restDay = RestDay(
                    athleteId: athleteId,
                    date: normalizedDate,
                    isPlanned: false,
                    reason: .detected
                )
                try await saveRestDay(restDay)
                insertedCount += 1
                existingDates.insert(normalizedDate)

                #if DEBUG
                print("🛏️ RestDayService: Logged rest day for \(normalizedDate)")
                #endif
            } catch {
                #if DEBUG
                print("🛏️ RestDayService: Failed to log rest day for \(normalizedDate): \(error)")
                #endif
            }
        }

        // Update last detection time
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastDetectionKey)

        // Refresh data
        await refreshData(athleteId: athleteId)

        #if DEBUG
        print("🛏️ RestDayService: Logged \(insertedCount) new rest days")
        #endif

        return insertedCount
    }

    /// Get rest days for the past N days
    func getRestDays(athleteId: Int, days: Int = 30) async throws -> [RestDay] {
        let response: [RestDayResponse] = try await supabase
            .from("rest_days")
            .select()
            .eq("athlete_id", value: athleteId)
            .gte("date", value: dateString(daysAgo: days))
            .order("date", ascending: false)
            .execute()
            .value

        return response.compactMap { $0.toRestDay() }
    }

    /// Save a rest day to the database
    func saveRestDay(_ restDay: RestDay) async throws {
        var data: [String: AnyEncodable] = [
            "athlete_id": AnyEncodable(restDay.athleteId),
            "date": AnyEncodable(dateOnlyString(from: restDay.date)),
            "is_planned": AnyEncodable(restDay.isPlanned),
            "reason": AnyEncodable(restDay.reason.rawValue),
            "recovery_benefit": AnyEncodable(restDay.recoveryBenefit)
        ]

        if let notes = restDay.notes {
            data["notes"] = AnyEncodable(notes)
        }

        // Upsert to handle duplicates
        _ = try await supabase
            .from("rest_days")
            .upsert(data, onConflict: "athlete_id,date")
            .execute()
    }

    /// Update a rest day (e.g., add notes or change reason)
    func updateRestDay(_ restDay: RestDay) async throws {
        var data: [String: AnyEncodable] = [
            "is_planned": AnyEncodable(restDay.isPlanned),
            "reason": AnyEncodable(restDay.reason.rawValue),
            "recovery_benefit": AnyEncodable(restDay.recoveryBenefit)
        ]

        if let notes = restDay.notes {
            data["notes"] = AnyEncodable(notes)
        }

        _ = try await supabase
            .from("rest_days")
            .update(data)
            .eq("id", value: restDay.id.uuidString)
            .execute()
    }

    /// Delete a rest day (e.g., if activity was added retroactively)
    func deleteRestDay(id: UUID) async throws {
        _ = try await supabase
            .from("rest_days")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Mark today or a specific date as a planned rest day
    func markAsRestDay(
        athleteId: Int,
        date: Date = Date(),
        reason: RestDayReason = .scheduled,
        notes: String? = nil
    ) async throws {
        let restDay = RestDay(
            athleteId: athleteId,
            date: date,
            isPlanned: true,
            reason: reason,
            notes: notes
        )

        try await saveRestDay(restDay)
        await refreshData(athleteId: athleteId)
    }

    /// Get consecutive rest days ending today or yesterday
    func getConsecutiveRestDays(athleteId: Int) async throws -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var count = 0
        var checkDate = today

        // Check backwards from today
        while true {
            let dateStr = dateOnlyString(from: checkDate)

            let response: [RestDayResponse] = try await supabase
                .from("rest_days")
                .select()
                .eq("athlete_id", value: athleteId)
                .eq("date", value: dateStr)
                .execute()
                .value

            if response.isEmpty {
                break
            }

            count += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previousDay
        }

        return count
    }

    /// Calculate recovery status based on rest days and training
    func calculateRecoveryStatus(athleteId: Int) async throws -> RecoveryStatus {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get last 14 days of data
        let restDays = try await getRestDays(athleteId: athleteId, days: 14)
        let activities = try await ActivityService.getAllActivitiesByUser(userId: athleteId, limit: 30)

        // Count rest days in last 7 days
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let recentRestDays = restDays.filter { $0.date >= sevenDaysAgo }
        let restDaysThisWeek = recentRestDays.count

        // Count training days in last 7 days
        let recentActivities = activities.filter {
            guard let ts = $0.activity_date ?? $0.start_date else { return false }
            return Date(timeIntervalSince1970: ts) >= sevenDaysAgo
        }
        let trainingDates: [Date] = recentActivities.compactMap {
            guard let ts = $0.activity_date ?? $0.start_date else { return nil }
            return calendar.startOfDay(for: Date(timeIntervalSince1970: ts))
        }
        let trainingDaysThisWeek = Set(trainingDates).count

        // Calculate days since last rest day
        let daysSinceRest: Int
        if let lastRestDay = restDays.first {
            daysSinceRest = calendar.dateComponents([.day], from: lastRestDay.date, to: today).day ?? 0
        } else {
            daysSinceRest = 14 // Assume no rest in 2 weeks
        }

        // Determine recovery status
        let status: RecoveryStatus

        if daysSinceRest <= 1 && restDaysThisWeek >= 2 {
            status = .fullyRecovered
        } else if daysSinceRest <= 2 && restDaysThisWeek >= 1 {
            status = .wellRested
        } else if daysSinceRest <= 4 || restDaysThisWeek >= 1 {
            status = .adequate
        } else if daysSinceRest <= 6 {
            status = .needsRest
        } else {
            status = .overdue
        }

        return status
    }

    /// Get rest day summary for a period
    func getRestDaySummary(athleteId: Int, days: Int = 30) async throws -> RestDaySummary {
        let restDays = try await getRestDays(athleteId: athleteId, days: days)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let periodStart = calendar.date(byAdding: .day, value: -days, to: today)!

        let plannedCount = restDays.filter { $0.isPlanned }.count
        let unplannedCount = restDays.filter { !$0.isPlanned }.count
        let averageBenefit = restDays.isEmpty ? 0.0 :
            Double(restDays.map { $0.recoveryBenefit }.reduce(0, +)) / Double(restDays.count)

        // Calculate current streak
        let currentStreakCount = try await getConsecutiveRestDays(athleteId: athleteId)

        // Calculate longest streak
        var longestStreak = 0
        var currentCount = 0
        var previousDate: Date?

        for restDay in restDays.sorted(by: { $0.date > $1.date }) {
            if let prev = previousDate {
                let dayDiff = calendar.dateComponents([.day], from: restDay.date, to: prev).day ?? 0
                if dayDiff == 1 {
                    currentCount += 1
                } else {
                    longestStreak = max(longestStreak, currentCount)
                    currentCount = 1
                }
            } else {
                currentCount = 1
            }
            previousDate = restDay.date
        }
        longestStreak = max(longestStreak, currentCount)

        return RestDaySummary(
            athleteId: athleteId,
            totalRestDays: restDays.count,
            plannedRestDays: plannedCount,
            unplannedRestDays: unplannedCount,
            averageRecoveryBenefit: averageBenefit,
            longestStreak: longestStreak,
            currentStreak: currentStreakCount,
            periodStart: periodStart,
            periodEnd: today
        )
    }

    /// Check if yesterday was a rest day (for readiness calculation)
    func wasYesterdayRestDay(athleteId: Int) async throws -> Bool {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else {
            return false
        }

        let dateStr = dateOnlyString(from: yesterday)

        let response: [RestDayResponse] = try await supabase
            .from("rest_days")
            .select()
            .eq("athlete_id", value: athleteId)
            .eq("date", value: dateStr)
            .execute()
            .value

        return !response.isEmpty
    }

    /// Refresh all rest day data
    func refreshData(athleteId: Int) async {
        do {
            recentRestDays = try await getRestDays(athleteId: athleteId, days: 30)
            currentStreak = try await getConsecutiveRestDays(athleteId: athleteId)
            recoveryStatus = try await calculateRecoveryStatus(athleteId: athleteId)
            cacheData()
        } catch {
            lastError = error
            #if DEBUG
            print("🛏️ RestDayService: Failed to refresh data: \(error)")
            #endif
        }
    }

    // MARK: - Readiness Integration

    /// Calculate rest day contribution to readiness score
    /// Returns a score 0-100 and a factor for display
    func calculateRestDayFactor(athleteId: Int) async throws -> (score: Int, description: String, trend: ReadinessFactor.FactorTrend) {
        let status = try await calculateRecoveryStatus(athleteId: athleteId)
        let daysSinceRest = try await getDaysSinceLastRest(athleteId: athleteId)

        let description: String
        let trend: ReadinessFactor.FactorTrend

        switch status {
        case .fullyRecovered:
            description = "Well rested"
            trend = .improving
        case .wellRested:
            description = "Good recovery"
            trend = .stable
        case .adequate:
            description = "Adequate"
            trend = .stable
        case .needsRest:
            description = "\(daysSinceRest) days training"
            trend = .declining
        case .overdue:
            description = "Rest overdue"
            trend = .declining
        }

        return (status.readinessScore, description, trend)
    }

    /// Get days since last rest day
    func getDaysSinceLastRest(athleteId: Int) async throws -> Int {
        let restDays = try await getRestDays(athleteId: athleteId, days: 30)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let lastRestDay = restDays.first else {
            return 30 // Default to 30 if no rest days found
        }

        return calendar.dateComponents([.day], from: lastRestDay.date, to: today).day ?? 0
    }

    // MARK: - Private Methods

    private func dateString(daysAgo: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return dateOnlyString(from: date)
    }

    private func dateOnlyString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func cacheData() {
        if let encoded = try? JSONEncoder().encode(recentRestDays) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }

    private func loadCachedData() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([RestDay].self, from: data) else {
            return
        }
        recentRestDays = cached
    }
}

// MARK: - Rest Day Detection Trigger

extension RestDayService {
    /// Check if rest day detection should run
    /// Returns true if last detection was more than 6 hours ago
    func shouldRunDetection() -> Bool {
        let lastDetection = UserDefaults.standard.double(forKey: lastDetectionKey)
        guard lastDetection > 0 else { return true }

        let lastDetectionDate = Date(timeIntervalSince1970: lastDetection)
        let hoursSinceDetection = Date().timeIntervalSince(lastDetectionDate) / 3600

        return hoursSinceDetection >= 6
    }

    /// Run detection if needed
    func runDetectionIfNeeded(athleteId: Int) async {
        guard shouldRunDetection() else { return }

        do {
            _ = try await detectAndLogRestDays(athleteId: athleteId)
        } catch {
            #if DEBUG
            print("🛏️ RestDayService: Auto-detection failed: \(error)")
            #endif
        }
    }
}
