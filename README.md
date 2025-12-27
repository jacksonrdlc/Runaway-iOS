# Runaway iOS

[![iOS CI/CD](https://github.com/jacksonrdlc/Runaway-iOS/actions/workflows/ios-build.yml/badge.svg)](https://github.com/jacksonrdlc/Runaway-iOS/actions/workflows/ios-build.yml)

A modern fitness tracking application that helps users monitor and visualize their athletic activities. The app provides real-time activity tracking, detailed statistics, and a widget for quick access to your fitness data.

## Features

- Real-time activity tracking and synchronization
- Athlete profile management
- Weekly and monthly activity statistics
- iOS Widget support for quick activity overview
- Beautiful UI with activity cards and charts
- Support for multiple activity types (Running, Walking, etc.)

## Tech Stack

### Languages
- Swift 5
- SwiftUI for UI components

### Frameworks & Libraries
- SwiftUI - Modern declarative UI framework
- WidgetKit - For iOS home screen widgets
- Supabase - Backend as a Service for:
  - Real-time data synchronization
  - User authentication
  - Database storage
- Charts - For data visualization
- Polyline - For map route encoding/decoding

## Prerequisites

- Xcode 15.0 or later
- iOS 16.0 or later
- CocoaPods (for dependency management)
- Supabase account and project

## Setup & Installation

1. Clone the repository:
```bash
git clone [your-repository-url]
cd "Runaway iOS"
```

2. Install dependencies using CocoaPods:
```bash
pod install
```

3. Create a `Config.xcconfig` file in the project root and add your Supabase credentials:
```
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

4. Open the workspace in Xcode:
```bash
open "Runaway iOS.xcworkspace"
```

5. Build and run the project in Xcode

## Database Schema

The app uses the following main tables in Supabase:
- `athletes` - User profiles and athlete information
- `activities` - Workout and activity records
- `athlete_stats` - Aggregated statistics for athletes

## Widget Setup

The app includes a home screen widget that displays:
- Weekly activity summary
- Recent activities
- Monthly mileage

To enable the widget, long press on your home screen and add the "Runaway" widget.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

All pull requests are automatically built and tested using our CI/CD pipeline. See [.github/CI_CD_DOCUMENTATION.md](.github/CI_CD_DOCUMENTATION.md) for more details.

## CI/CD

This project uses GitHub Actions for continuous integration. The pipeline:
- ✅ Builds the iOS app with Xcode 15.2
- ✅ Runs unit tests
- ✅ Performs code quality checks with SwiftLint
- ✅ Builds the widget extension

See the [CI/CD Documentation](.github/CI_CD_DOCUMENTATION.md) for configuration details and troubleshooting.

## License

[Your chosen license]

## Contact

Your Name - [@your_twitter](https://twitter.com/your_twitter) - email@example.com

Project Link: [https://github.com/yourusername/Runaway-iOS](https://github.com/yourusername/Runaway-iOS)
