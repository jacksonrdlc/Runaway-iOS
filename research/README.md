# Daily Research Briefs

This folder contains AI-generated daily research briefs for improving the Runaway iOS app.

## What's Inside

Each morning at 6 AM UTC, an automated Edge Function generates a comprehensive research brief covering:

- **Emerging Fitness Technology** - Latest innovations in wearables, sensors, and tracking
- **AI & Machine Learning** - On-device ML, personalization, and intelligent features
- **Competitive Analysis** - What top apps (Strava, Nike Run Club, etc.) are doing well
- **iOS Architecture & Performance** - SwiftUI optimization, background tasks, battery efficiency
- **Health & Wellness Integration** - HealthKit, readiness scoring, recovery science

## File Naming

Files are named with timestamps: `YYYY-MM-DD-daily-brief.md`

## How It Works

1. A Supabase Edge Function (`daily-research-brief`) runs at 6 AM UTC
2. It uses Claude AI to research each topic with deep, actionable insights
3. The resulting markdown file is committed directly to this repository
4. You get a fresh "morning paper" of improvements to consider!

## Action Items

Each brief includes:
- **Top 3 Action Items** - High-impact improvements for the week
- **Quick Wins** - Small improvements (< 2 hours each)
- **Long-term Roadmap** - Major features for future planning

## Configuration

The Edge Function requires these secrets in Supabase:
- `ANTHROPIC_API_KEY` - For Claude AI research
- `GITHUB_TOKEN` - For committing files (needs repo write access)
- `GITHUB_REPO_OWNER` - Repository owner (default: runaway-labs)
- `GITHUB_REPO_NAME` - Repository name (default: Runaway-iOS)

---

*Generated briefs are AI-assisted research suggestions. Always review recommendations critically and adapt to your specific needs.*
