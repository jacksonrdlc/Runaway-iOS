import SwiftUI

// MARK: - App Theme
struct AppTheme {
    // MARK: - Colors
    struct Colors {
        // Primary Brand Colors
        static let primary = Color(red: 0.2, green: 0.6, blue: 1.0) // Vibrant Blue
        static let primaryDark = Color(red: 0.1, green: 0.4, blue: 0.8)
        static let accent = Color(red: 0.0, green: 0.8, blue: 0.4) // Energetic Green
        
        // Background Colors
        static let background = Color(red: 0.02, green: 0.02, blue: 0.08) // Ultra Dark Blue/Black
        static let cardBackground = Color(red: 0.05, green: 0.05, blue: 0.12)
        static let surfaceBackground = Color(red: 0.08, green: 0.08, blue: 0.15)
        
        // Text Colors
        static let primaryText = Color.white
        static let secondaryText = Color(red: 0.7, green: 0.7, blue: 0.8)
        static let mutedText = Color(red: 0.5, green: 0.5, blue: 0.6)
        
        // Status Colors
        static let success = Color(red: 0.0, green: 0.8, blue: 0.4)
        static let warning = Color(red: 1.0, green: 0.6, blue: 0.0)
        static let error = Color(red: 1.0, green: 0.3, blue: 0.3)
        
        // Gradient Colors
        static let primaryGradient = LinearGradient(
            colors: [primary, primaryDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let accentGradient = LinearGradient(
            colors: [accent, Color(red: 0.0, green: 0.6, blue: 0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.system(size: 32, weight: .bold, design: .rounded)
        static let title = Font.system(size: 24, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 16, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
    }
}

// MARK: - View Extensions
extension View {
    func primaryCard() -> some View {
        self
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    func surfaceCard() -> some View {
        self
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.surfaceBackground)
            .cornerRadius(AppTheme.CornerRadius.large)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    func primaryButton() -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.Colors.primaryGradient)
            .foregroundColor(.white)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    func secondaryButton() -> some View {
        self
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .background(AppTheme.Colors.surfaceBackground)
            .foregroundColor(AppTheme.Colors.primaryText)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .stroke(AppTheme.Colors.primary, lineWidth: 1)
            )
    }
}

// MARK: - SF Symbols
struct AppIcons {
    // Tab Bar Icons
    static let activities = "figure.run"
    static let analysis = "chart.line.uptrend.xyaxis"
    static let athlete = "person.crop.circle.fill"
    
    // Metrics Icons
    static let distance = "road.lanes"
    static let pace = "speedometer"
    static let time = "stopwatch"
    static let consistency = "calendar.badge.clock"
    
    // Performance Icons
    static let improving = "arrow.up.circle.fill"
    static let stable = "minus.circle.fill"
    static let declining = "arrow.down.circle.fill"
    
    // Action Icons
    static let refresh = "arrow.clockwise"
    static let settings = "gearshape.fill"
    static let signOut = "rectangle.portrait.and.arrow.right"
    static let analyze = "brain.head.profile"
}