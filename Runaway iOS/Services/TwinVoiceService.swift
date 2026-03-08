//
//  TwinVoiceService.swift
//  Runaway iOS
//
//  Service for generating declarative, data-backed twin voice insights
//

import Foundation

class TwinVoiceService {
    
    struct TwinInsight {
        let message: String
        let submessage: String?
        let urgency: UrgencyLevel
    }
    
    enum UrgencyLevel {
        case low, medium, high, critical
    }
    
    /// Generate a punchy insight based on the current phase and training load
    static func generateInsight(
        phase: TrainingPhase,
        acwr: Double,
        weeklyVolumeKm: Double,
        volumeChange: Double
    ) -> TwinInsight {
        
        let volumeMiles = weeklyVolumeKm * 0.621371
        
        switch phase {
        case .raceDay:
            return TwinInsight(
                message: "It's time. What do you run on?",
                submessage: "Trust the process. You're ready.",
                urgency: .critical
            )
            
        case .raceWeek:
            return TwinInsight(
                message: "Final preparations. Low volume, high focus.",
                submessage: "Rest is your only job now.",
                urgency: .high
            )
            
        case .taper:
            if acwr < 0.9 {
                return TwinInsight(
                    message: "You're tapering. Your ratio is dropping — as planned.",
                    submessage: "Legs are building snap.",
                    urgency: .medium
                )
            } else {
                return TwinInsight(
                    message: "Trust your training. The work is done.",
                    submessage: "Focus on recovery and fuel.",
                    urgency: .medium
                )
            }
            
        case .peak:
            if acwr > 1.4 {
                return TwinInsight(
                    message: "Intensity is high. Your ratio is \(String(format: "%.2f", acwr)).",
                    submessage: "You're flirting with the edge. Prioritize sleep.",
                    urgency: .high
                )
            } else {
                return TwinInsight(
                    message: "This is the peak. Volume is \(String(format: "%.0f", volumeMiles)) miles.",
                    submessage: "Maintain focus. These are the miles that matter.",
                    urgency: .medium
                )
            }
            
        case .build:
            return TwinInsight(
                message: "Final build phase. The heavy lifting starts now.",
                submessage: "\(String(format: "%+.0f%%", volumeChange)) volume increase vs last week.",
                urgency: .medium
            )
            
        case .base:
            return TwinInsight(
                message: "Laying the foundation. Aerobic engine building.",
                submessage: "Consistent miles at low intensity.",
                urgency: .low
            )
            
        case .rampingUp:
            return TwinInsight(
                message: "You're building. \(String(format: "%.0f", volumeMiles)) miles this week.",
                submessage: "Maintain the 10% rule for safety.",
                urgency: .medium
            )
            
        case .steady:
            return TwinInsight(
                message: "Great consistency. You're holding steady.",
                submessage: "Perfect platform for your next build.",
                urgency: .low
            )
            
        case .recovery:
            return TwinInsight(
                message: "Body sent a signal. Your HRV says you're fatigued.",
                submessage: "This isn't a setback. It's data.",
                urgency: .high
            )
            
        case .detraining:
            return TwinInsight(
                message: "Welcome back. We'll start easy.",
                submessage: "Your fitness dropped, but your memory didn't.",
                urgency: .medium
            )
            
        case .newUser:
            return TwinInsight(
                message: "Your twin is learning who you are.",
                submessage: "Give it a few more runs to find your baseline.",
                urgency: .low
            )
        }
    }
}
