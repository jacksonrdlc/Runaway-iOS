import Foundation
import Supabase
import HealthKit

class BiometricService {
    static let shared = BiometricService()
    
    private let reader = HealthKitDataReader()
    
    func syncHealthData() async {
        guard let athleteId = await UserSession.shared.userId else { return }
        
        do {
            // Fetch yesterday and today
            let calendar = Calendar.current
            let dates = [calendar.date(byAdding: .day, value: -1, to: Date())!, Date()]
            
            for date in dates {
                let entryDate = ISO8601DateFormatter.justDate.string(from: date)
                
                // Read from HealthKit
                let sleep = try? await reader.fetchSleepAnalysis(for: date)
                let hrv = try? await reader.fetchHRVData(for: date)
                let rhr = try? await reader.fetchRestingHeartRate(for: date)
                
                // Calculate readiness (simplified Twin logic)
                let readiness = calculateReadiness(hrv: hrv, sleep: sleep, rhr: rhr)
                
                let biometric = AthleteBiometric(
                    id: nil,
                    athleteId: athleteId,
                    entryDate: entryDate,
                    hrvMs: hrv?.latestHRV,
                    rhrBpm: rhr?.value,
                    sleepScore: sleep?.qualityScore,
                    readinessScore: readiness.score,
                    recoveryPhase: readiness.phase,
                    stressLevel: nil,
                    rawSource: "apple_health"
                )
                
                // Upsert to Supabase
                try await supabase.from("athlete_biometrics")
                    .upsert(biometric, onConflict: "athlete_id, entry_date")
                    .execute()
            }
            
            #if DEBUG
            print("✅ BiometricService: Health data synced")
            #endif
        } catch {
            #if DEBUG
            print("❌ BiometricService: Sync failed: \(error)")
            #endif
        }
    }
    
    private func calculateReadiness(hrv: HealthKitDataReader.HRVData?, sleep: HealthKitDataReader.SleepAnalysis?, rhr: HealthKitDataReader.RestingHRData?) -> (score: Int, phase: String) {
        // Basic weights: 40% HRV, 40% Sleep, 20% RHR
        var score = 70.0 // Baseline
        
        if let hrvScore = hrv?.score {
            score = (score * 0.6) + (Double(hrvScore) * 0.4)
        }
        
        if let sleepScore = sleep?.qualityScore {
            score = (score * 0.6) + (Double(sleepScore) * 0.4)
        }
        
        if let rhrScore = rhr?.score {
            score = (score * 0.8) + (Double(rhrScore) * 0.2)
        }
        
        let finalScore = Int(score)
        var phase = "productive"
        
        if finalScore > 85 { phase = "peaking" }
        else if finalScore < 60 { phase = "strained" }
        else if finalScore < 45 { phase = "overreaching" }
        
        return (finalScore, phase)
    }
}

extension ISO8601DateFormatter {
    static let justDate: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}
