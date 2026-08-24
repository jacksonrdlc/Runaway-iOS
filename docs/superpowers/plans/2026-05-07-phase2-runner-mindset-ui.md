# Phase 2 — Runner Mindset UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface the runner identity and mindset system (Phase 1 backend) as iOS UI: a new onboarding step, a Profile identity card, a milestones section, and a reusable edit sheet.

**Architecture:** Three new files (`MindsetModels.swift`, `RunnerMindsetService.swift`, `EditRunnerMindsetView.swift`) plus targeted edits to the onboarding enum, onboarding container, onboarding step views, and AthleteView. The word "Adlerian" never appears in any iOS file name, UI label, or user-facing string.

**Tech Stack:** Swift 5.9, SwiftUI, Supabase iOS SDK (global `supabase` singleton), `@Observable` where already adopted; `OnboardingViewModel` remains `ObservableObject`/`@Published`.

---

## File Map

| Action | File |
|--------|------|
| Create | `Runaway iOS/Models/MindsetModels.swift` |
| Create | `Runaway iOS/Services/RunnerMindsetService.swift` |
| Create | `Runaway iOS/Views/EditRunnerMindsetView.swift` |
| Modify | `Runaway iOS/Models/OnboardingModels.swift` |
| Modify | `Runaway iOS/Views/Onboarding/OnboardingStepViews.swift` |
| Modify | `Runaway iOS/Views/Onboarding/OnboardingContainerView.swift` |
| Modify | `Runaway iOS/Views/AthleteView.swift` |

---

## Task 1: MindsetModels + RunnerMindsetService

**Files:**
- Create: `Runaway iOS/Models/MindsetModels.swift`
- Create: `Runaway iOS/Services/RunnerMindsetService.swift`

- [ ] **Step 1: Create MindsetModels.swift**

```swift
// Runaway iOS/Models/MindsetModels.swift
import Foundation

struct MindsetProfile {
    let runnerIdentity: String
    let identitySummary: String
    let whyIRun: String
    let coreValues: [String]
}

struct RunnerIdentityMilestone: Identifiable, Decodable {
    let id: UUID
    let milestoneKey: String
    let label: String
    let description: String
    let earned: Bool
    let earnedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case milestoneKey  = "milestone_key"
        case label
        case description
        case earned
        case earnedAt      = "earned_at"
    }
}
```

- [ ] **Step 2: Create RunnerMindsetService.swift**

```swift
// Runaway iOS/Services/RunnerMindsetService.swift
import Foundation

struct RunnerMindsetService {

    // MARK: - Fetch profile from core_memory

    static func fetchProfile(athleteId: Int) async throws -> MindsetProfile? {
        struct Row: Decodable {
            let coreMemory: [String: AnyCodable]?
            enum CodingKeys: String, CodingKey {
                case coreMemory = "core_memory"
            }
        }

        let rows: [Row] = try await supabase
            .from("athlete_ai_profiles")
            .select("core_memory")
            .eq("athlete_id", value: athleteId)
            .execute()
            .value

        guard let row = rows.first,
              let coreMemory = row.coreMemory,
              let profileRaw = coreMemory["adlerian_profile"]?.value as? [String: Any] else {
            return nil
        }

        guard
            let identity = profileRaw["runner_identity"] as? String,
            let summary  = profileRaw["identity_summary"] as? String,
            let why      = profileRaw["why_i_run"] as? String,
            let values   = profileRaw["core_values"] as? [String]
        else { return nil }

        return MindsetProfile(
            runnerIdentity: identity,
            identitySummary: summary,
            whyIRun: why,
            coreValues: values
        )
    }

    // MARK: - Save via edge function

    static func saveProfile(
        athleteId: Int,
        whyIRun: String,
        coreValues: [String]
    ) async throws -> MindsetProfile {
        struct Request: Encodable {
            let athlete_id: Int
            let why_i_run: String
            let core_values: [String]
            let mode: String
        }
        struct Response: Decodable {
            let runner_identity: String
            let identity_summary: String
            let why_i_run: String
            let core_values: [String]
        }

        let response: Response = try await supabase.functions.invoke(
            "identity-profile",
            options: .init(body: Request(
                athlete_id: athleteId,
                why_i_run: whyIRun,
                core_values: coreValues,
                mode: "update"
            ))
        )

        return MindsetProfile(
            runnerIdentity: response.runner_identity,
            identitySummary: response.identity_summary,
            whyIRun: response.why_i_run,
            coreValues: response.core_values
        )
    }

    // MARK: - Fetch milestones

    static func fetchMilestones(athleteId: Int) async throws -> [RunnerIdentityMilestone] {
        let milestones: [RunnerIdentityMilestone] = try await supabase
            .from("runner_identity_milestones")
            .select()
            .eq("athlete_id", value: athleteId)
            .order("earned", ascending: false)
            .order("created_at", ascending: true)
            .execute()
            .value
        return milestones
    }
}
```

- [ ] **Step 3: Verify the file compiles (no Xcode build yet — just check for obvious issues)**

`AnyCodable` may not exist in this project. Check if it's already used elsewhere:
```bash
grep -r "AnyCodable" "Runaway iOS/" --include="*.swift" | head -5
```

If `AnyCodable` is not present, replace the `Row` struct in `fetchProfile` with a raw JSON decode approach:

```swift
// Alternative fetchProfile implementation without AnyCodable
static func fetchProfile(athleteId: Int) async throws -> MindsetProfile? {
    struct Row: Decodable {
        let coreMemory: Data?
        enum CodingKeys: String, CodingKey {
            case coreMemory = "core_memory"
        }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // core_memory comes as a JSON object — decode as raw JSONObject
            if let jsonObject = try? container.decode(JSONObject.self, forKey: .coreMemory) {
                coreMemory = try? JSONEncoder().encode(jsonObject)
            } else {
                coreMemory = nil
            }
        }
    }
    // ...
}
```

Actually, the simplest approach that avoids type-erasure gymnastics is to decode `core_memory` as `String` (Supabase returns JSONB as a string when using `.value` decode), then parse manually:

```swift
// Final fetchProfile — replace the earlier version with this:
static func fetchProfile(athleteId: Int) async throws -> MindsetProfile? {
    struct Row: Decodable {
        let coreMemory: CoreMemory?
        enum CodingKeys: String, CodingKey { case coreMemory = "core_memory" }
    }
    struct CoreMemory: Decodable {
        let adlerianProfile: AdlerianProfile?
        enum CodingKeys: String, CodingKey { case adlerianProfile = "adlerian_profile" }
    }
    struct AdlerianProfile: Decodable {
        let runnerIdentity: String
        let identitySummary: String
        let whyIRun: String
        let coreValues: [String]
        enum CodingKeys: String, CodingKey {
            case runnerIdentity  = "runner_identity"
            case identitySummary = "identity_summary"
            case whyIRun         = "why_i_run"
            case coreValues      = "core_values"
        }
    }

    let rows: [Row] = try await supabase
        .from("athlete_ai_profiles")
        .select("core_memory")
        .eq("athlete_id", value: athleteId)
        .execute()
        .value

    guard let profile = rows.first?.coreMemory?.adlerianProfile else { return nil }
    return MindsetProfile(
        runnerIdentity: profile.runnerIdentity,
        identitySummary: profile.identitySummary,
        whyIRun: profile.whyIRun,
        coreValues: profile.coreValues
    )
}
```

Use this final version — delete the `AnyCodable`-based version entirely. The complete `RunnerMindsetService.swift` with this fix applied:

```swift
// Runaway iOS/Services/RunnerMindsetService.swift
import Foundation

struct RunnerMindsetService {

    static func fetchProfile(athleteId: Int) async throws -> MindsetProfile? {
        struct Row: Decodable {
            let coreMemory: CoreMemory?
            enum CodingKeys: String, CodingKey { case coreMemory = "core_memory" }
        }
        struct CoreMemory: Decodable {
            let adlerianProfile: AdlerianProfile?
            enum CodingKeys: String, CodingKey { case adlerianProfile = "adlerian_profile" }
        }
        struct AdlerianProfile: Decodable {
            let runnerIdentity: String
            let identitySummary: String
            let whyIRun: String
            let coreValues: [String]
            enum CodingKeys: String, CodingKey {
                case runnerIdentity  = "runner_identity"
                case identitySummary = "identity_summary"
                case whyIRun         = "why_i_run"
                case coreValues      = "core_values"
            }
        }

        let rows: [Row] = try await supabase
            .from("athlete_ai_profiles")
            .select("core_memory")
            .eq("athlete_id", value: athleteId)
            .execute()
            .value

        guard let profile = rows.first?.coreMemory?.adlerianProfile else { return nil }
        return MindsetProfile(
            runnerIdentity: profile.runnerIdentity,
            identitySummary: profile.identitySummary,
            whyIRun: profile.whyIRun,
            coreValues: profile.coreValues
        )
    }

    static func saveProfile(
        athleteId: Int,
        whyIRun: String,
        coreValues: [String]
    ) async throws -> MindsetProfile {
        struct Request: Encodable {
            let athlete_id: Int
            let why_i_run: String
            let core_values: [String]
            let mode: String
        }
        struct Response: Decodable {
            let runner_identity: String
            let identity_summary: String
            let why_i_run: String
            let core_values: [String]
        }

        let response: Response = try await supabase.functions.invoke(
            "identity-profile",
            options: .init(body: Request(
                athlete_id: athleteId,
                why_i_run: whyIRun,
                core_values: coreValues,
                mode: "update"
            ))
        )

        return MindsetProfile(
            runnerIdentity: response.runner_identity,
            identitySummary: response.identity_summary,
            whyIRun: response.why_i_run,
            coreValues: response.core_values
        )
    }

    static func fetchMilestones(athleteId: Int) async throws -> [RunnerIdentityMilestone] {
        let milestones: [RunnerIdentityMilestone] = try await supabase
            .from("runner_identity_milestones")
            .select()
            .eq("athlete_id", value: athleteId)
            .order("earned", ascending: false)
            .order("created_at", ascending: true)
            .execute()
            .value
        return milestones
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add "Runaway iOS/Models/MindsetModels.swift" "Runaway iOS/Services/RunnerMindsetService.swift"
git commit -m "feat: add MindsetModels and RunnerMindsetService for runner identity"
```

---

## Task 2: EditRunnerMindsetView (reusable sheet)

**Files:**
- Create: `Runaway iOS/Views/EditRunnerMindsetView.swift`

- [ ] **Step 1: Create EditRunnerMindsetView.swift**

```swift
// Runaway iOS/Views/EditRunnerMindsetView.swift
import SwiftUI

struct EditRunnerMindsetView: View {
    let athleteId: Int
    let existing: MindsetProfile?
    let onSave: (MindsetProfile) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var whyIRun: String = ""
    @State private var selectedValues: [String] = []
    @State private var isSaving = false
    @State private var saveError: String? = nil

    private let presetValues = [
        "consistency", "mental health", "stress relief", "community",
        "competition", "adventure", "fitness", "routine", "solitude", "speed"
    ]

    private var canSave: Bool {
        whyIRun.trimmingCharacters(in: .whitespaces).count >= 10 && !selectedValues.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.DarkMode.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {

                        if let error = saveError {
                            Text(error)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.red)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // WHY I RUN
                        VStack(alignment: .leading, spacing: 10) {
                            EyebrowLabel(text: "WHY I RUN")
                            ZStack(alignment: .topLeading) {
                                if whyIRun.isEmpty {
                                    Text("I run to clear my head and feel strong")
                                        .font(.system(size: 15, design: .rounded))
                                        .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 12)
                                }
                                TextEditor(text: $whyIRun)
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .frame(minHeight: 100)
                                    .onChange(of: whyIRun) { _, newValue in
                                        if newValue.count > 200 {
                                            whyIRun = String(newValue.prefix(200))
                                        }
                                    }
                            }
                            .background(AppTheme.Colors.DarkMode.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))

                            Text("\(whyIRun.count)/200")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        // WHAT MATTERS MOST
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                EyebrowLabel(text: "WHAT MATTERS MOST")
                                Spacer()
                                Text("Pick up to 3")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                            }
                            ValueChipGrid(
                                values: presetValues,
                                selected: $selectedValues,
                                maxSelected: 3
                            )
                        }

                        // Save button
                        Button {
                            Task { await handleSave() }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.black)
                                        .scaleEffect(0.85)
                                } else {
                                    Text("Save")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(canSave && !isSaving
                                ? AppTheme.Colors.warmAmber
                                : AppTheme.Colors.warmAmber.opacity(0.3))
                            .foregroundColor(canSave && !isSaving ? .black : .black.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canSave || isSaving)

                    }
                    .padding(20)
                }
            }
            .navigationTitle("Running Mindset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.Colors.warmAmber)
                }
            }
        }
        .onAppear {
            if let existing {
                whyIRun = existing.whyIRun
                selectedValues = existing.coreValues
            }
        }
    }

    private func handleSave() async {
        isSaving = true
        saveError = nil
        do {
            let profile = try await RunnerMindsetService.saveProfile(
                athleteId: athleteId,
                whyIRun: whyIRun.trimmingCharacters(in: .whitespaces),
                coreValues: selectedValues
            )
            await MainActor.run {
                onSave(profile)
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                saveError = "Couldn't save — try again"
            }
        }
    }
}

// MARK: - Value Chip Grid

private struct ValueChipGrid: View {
    let values: [String]
    @Binding var selected: [String]
    let maxSelected: Int

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(values, id: \.self) { value in
                let isSelected = selected.contains(value)
                Button {
                    toggleValue(value)
                } label: {
                    Text(isSelected ? "✓ \(value)" : value)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                        .foregroundColor(isSelected ? AppTheme.Colors.warmAmber : AppTheme.Colors.DarkMode.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected
                            ? AppTheme.Colors.warmAmber.opacity(0.12)
                            : AppTheme.Colors.DarkMode.cardBackground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                isSelected ? AppTheme.Colors.warmAmber : Color.white.opacity(0.12),
                                lineWidth: 1
                            )
                        )
                }
            }
        }
    }

    private func toggleValue(_ value: String) {
        if let index = selected.firstIndex(of: value) {
            selected.remove(at: index)
        } else if selected.count < maxSelected {
            selected.append(value)
        } else {
            selected.removeFirst()
            selected.append(value)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map(\.sizeThatFits(.unspecified).height).max() ?? 0 }.reduce(0, +)
            + CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var rowWidth: CGFloat = 0
        let maxWidth = proposal.width ?? .infinity
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(subview)
            rowWidth += size.width + spacing
        }
        return rows
    }
}
```

- [ ] **Step 2: Check if FlowLayout already exists in the project**

```bash
grep -r "FlowLayout\|struct FlowLayout" "Runaway iOS/" --include="*.swift" | head -5
```

If `FlowLayout` already exists elsewhere, remove it from `EditRunnerMindsetView.swift` (keep only the reference). If it doesn't exist, keep it in this file.

- [ ] **Step 3: Commit**

```bash
git add "Runaway iOS/Views/EditRunnerMindsetView.swift"
git commit -m "feat: add EditRunnerMindsetView sheet for runner mindset input"
```

---

## Task 3: OnboardingModels.swift — add runnerMindset step

**Files:**
- Modify: `Runaway iOS/Models/OnboardingModels.swift`

The new step `runnerMindset` is inserted between `movementTest` (4) and `locationPermission`. This requires renumbering: `locationPermission` becomes 6, `coachSelection` becomes 7, `completion` becomes 8.

- [ ] **Step 1: Add runnerMindset case and renumber later steps**

In `OnboardingModels.swift`, find the `OnboardingStep` enum and apply these changes:

Old:
```swift
enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome = 0
    case profileSetup = 1
    case goalsSetup = 2
    case experienceAssessment = 3
    case movementTest = 4
    case locationPermission = 5
    case coachSelection = 6
    case completion = 7
```

New:
```swift
enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome = 0
    case profileSetup = 1
    case goalsSetup = 2
    case experienceAssessment = 3
    case movementTest = 4
    case runnerMindset = 5
    case locationPermission = 6
    case coachSelection = 7
    case completion = 8
```

- [ ] **Step 2: Add title/subtitle/icon for runnerMindset**

In the `title` computed property, add:
```swift
case .runnerMindset: return "Your Mindset"
```

In the `subtitle` computed property, add:
```swift
case .runnerMindset: return "What drives you to run"
```

In the `icon` computed property, add:
```swift
case .runnerMindset: return "brain.head.profile"
```

- [ ] **Step 3: Add isSkippable for runnerMindset**

Current:
```swift
var isSkippable: Bool {
    switch self {
    case .welcome, .profileSetup, .goalsSetup, .completion: return false
    case .experienceAssessment, .movementTest, .locationPermission, .coachSelection: return true
    }
}
```

New:
```swift
var isSkippable: Bool {
    switch self {
    case .welcome, .profileSetup, .goalsSetup, .completion: return false
    case .experienceAssessment, .movementTest, .runnerMindset, .locationPermission, .coachSelection: return true
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add "Runaway iOS/Models/OnboardingModels.swift"
git commit -m "feat: add runnerMindset step to OnboardingStep enum (step 5)"
```

---

## Task 4: OnboardingStepViews + OnboardingContainerView — wire up new step

**Files:**
- Modify: `Runaway iOS/Views/Onboarding/OnboardingStepViews.swift`
- Modify: `Runaway iOS/Views/Onboarding/OnboardingContainerView.swift`

### Part A — RunnerMindsetStepView in OnboardingStepViews.swift

- [ ] **Step 1: Add RunnerMindsetStepView at the end of OnboardingStepViews.swift**

Append this to the file (after the last existing `struct`):

```swift
// MARK: - Runner Mindset Step

struct RunnerMindsetStepView: View {
    let onContinue: (String, [String]) -> Void
    let onSkip: () -> Void

    @State private var whyIRun: String = ""
    @State private var selectedValues: [String] = []
    @State private var isSaving = false
    @State private var saveError: String? = nil

    private let presetValues = [
        "consistency", "mental health", "stress relief", "community",
        "competition", "adventure", "fitness", "routine", "solitude", "speed"
    ]

    private var canContinue: Bool {
        whyIRun.trimmingCharacters(in: .whitespaces).count >= 10 && !selectedValues.isEmpty
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Spacer().frame(height: 8)

                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your Running Mindset")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("Understanding why you run helps your AI coach support you better.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    if let error = saveError {
                        Text(error)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // WHY I RUN
                    VStack(alignment: .leading, spacing: 10) {
                        Text("WHY I RUN")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .kerning(1.2)

                        ZStack(alignment: .topLeading) {
                            if whyIRun.isEmpty {
                                Text("I run to clear my head and feel strong")
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(Color(.tertiaryLabel))
                                    .padding(.horizontal, 12)
                                    .padding(.top, 12)
                            }
                            TextEditor(text: $whyIRun)
                                .font(.system(size: 15, design: .rounded))
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .frame(minHeight: 100)
                                .onChange(of: whyIRun) { _, newValue in
                                    if newValue.count > 200 {
                                        whyIRun = String(newValue.prefix(200))
                                    }
                                }
                        }
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("\(whyIRun.count)/200")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    // WHAT MATTERS MOST
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("WHAT MATTERS MOST")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                .kerning(1.2)
                            Spacer()
                            Text("Pick up to 3")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        OnboardingChipGrid(
                            values: presetValues,
                            selected: $selectedValues,
                            maxSelected: 3
                        )
                    }

                    // Continue button
                    Button {
                        onContinue(
                            whyIRun.trimmingCharacters(in: .whitespaces),
                            selectedValues
                        )
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            } else {
                                Text("Continue")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(canContinue ? Color.accentColor : Color.accentColor.opacity(0.3))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canContinue || isSaving)

                    // Skip link
                    Button {
                        onSkip()
                    } label: {
                        Text("Skip for now")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Onboarding Chip Grid

private struct OnboardingChipGrid: View {
    let values: [String]
    @Binding var selected: [String]
    let maxSelected: Int

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(values, id: \.self) { value in
                let isSelected = selected.contains(value)
                Button {
                    toggleValue(value)
                } label: {
                    Text(isSelected ? "✓ \(value)" : value)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                        .foregroundColor(isSelected ? Color.accentColor : Color(.secondaryLabel))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected
                            ? Color.accentColor.opacity(0.12)
                            : Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                isSelected ? Color.accentColor : Color(.separator),
                                lineWidth: 1
                            )
                        )
                }
            }
        }
    }

    private func toggleValue(_ value: String) {
        if let index = selected.firstIndex(of: value) {
            selected.remove(at: index)
        } else if selected.count < maxSelected {
            selected.append(value)
        } else {
            selected.removeFirst()
            selected.append(value)
        }
    }
}
```

**Important:** `FlowLayout` is already defined in `EditRunnerMindsetView.swift`. `OnboardingStepViews.swift` uses it without redeclaring it — both files are in the same module, so there's no import needed and no duplicate definition. Do NOT redefine `FlowLayout` here.

### Part B — OnboardingContainerView.swift

- [ ] **Step 2: Add viewModel properties for mindset step**

In `OnboardingViewModel`, add two `@Published` properties after the existing profile setup fields block:

```swift
// Mindset step fields
@Published var mindsetWhyIRun: String = ""
@Published var mindsetCoreValues: [String] = []
```

- [ ] **Step 3: Register RunnerMindsetStepView in the TabView**

In `OnboardingContainerView.body`, inside the `TabView`, insert the new step **after** the `.movementTest` entry and **before** the `.locationPermission` entry:

```swift
RunnerMindsetStepView(
    onContinue: { why, values in
        viewModel.mindsetWhyIRun = why
        viewModel.mindsetCoreValues = values
        viewModel.saveMindsetAndAdvance()
    },
    onSkip: viewModel.skipStep
)
.tag(OnboardingStep.runnerMindset)
```

- [ ] **Step 4: Add saveMindsetAndAdvance() to OnboardingViewModel**

Add this method to `OnboardingViewModel`:

```swift
func saveMindsetAndAdvance() {
    guard let athleteId = athleteId,
          !mindsetWhyIRun.isEmpty,
          !mindsetCoreValues.isEmpty else {
        nextStep()
        return
    }
    Task {
        try? await RunnerMindsetService.saveProfile(
            athleteId: athleteId,
            whyIRun: mindsetWhyIRun,
            coreValues: mindsetCoreValues
        )
        await MainActor.run { nextStep() }
    }
}
```

The save is fire-and-forget style: if it fails, `nextStep()` is still called so the user progresses. The identity card in Profile will show the "Set your running mindset" prompt if the save didn't succeed.

- [ ] **Step 5: Commit**

```bash
git add "Runaway iOS/Views/Onboarding/OnboardingStepViews.swift" \
        "Runaway iOS/Views/Onboarding/OnboardingContainerView.swift"
git commit -m "feat: add RunnerMindsetStepView to onboarding (step 5)"
```

---

## Task 5: AthleteView — identity card, milestones section, ACCOUNT row

**Files:**
- Modify: `Runaway iOS/Views/AthleteView.swift`

### Overview of changes

1. Add state vars for mindset data
2. Load mindset + milestones in `.task`
3. Insert identity card section (after profile header, before LIFETIME)
4. Insert milestones section (after identity card, before LIFETIME)
5. Add "Running Mindset" row to ACCOUNT section
6. Add `MilestoneRow` private struct
7. Add `showingEditMindset` sheet modifier

- [ ] **Step 1: Add state vars and showingEditMindset to AthleteView**

The struct `AthleteView` currently has:
```swift
@State private var personalBests: [PersonalBest] = []
@State private var isLoadingPRs = false
```

Add after those:
```swift
@State private var mindsetProfile: MindsetProfile? = nil
@State private var milestones: [RunnerIdentityMilestone] = []
@State private var mindsetLoadError = false
@State private var showingEditMindset = false
```

- [ ] **Step 2: Extend the .task to also load mindset data**

Current `.task`:
```swift
.task {
    guard let athleteId = athlete.id else { return }
    isLoadingPRs = true
    defer { isLoadingPRs = false }
    do {
        personalBests = try await PersonalBestService.shared.recomputeAndSave(athleteId: athleteId)
    } catch {
        personalBests = (try? await PersonalBestService.shared.fetchPRs(athleteId: athleteId)) ?? []
    }
}
```

Replace with:
```swift
.task {
    guard let athleteId = athlete.id else { return }

    // Load PRs and mindset data concurrently
    isLoadingPRs = true
    async let prResult: [PersonalBest] = {
        do {
            return try await PersonalBestService.shared.recomputeAndSave(athleteId: athleteId)
        } catch {
            return (try? await PersonalBestService.shared.fetchPRs(athleteId: athleteId)) ?? []
        }
    }()
    async let profileResult = RunnerMindsetService.fetchProfile(athleteId: athleteId)
    async let milestonesResult = RunnerMindsetService.fetchMilestones(athleteId: athleteId)

    personalBests = await prResult
    isLoadingPRs = false

    do {
        mindsetProfile = try await profileResult
    } catch {
        mindsetLoadError = true
    }
    milestones = (try? await milestonesResult) ?? []
}
```

- [ ] **Step 3: Add identity card section to the ScrollView body**

In the `ScrollView > VStack` in `body`, insert the identity card **before** the `// ── LIFETIME` block:

```swift
// ── MINDSET ────────────────────────────────────────────
VStack(alignment: .leading, spacing: 10) {
    EyebrowLabel(text: "MINDSET")
    if mindsetLoadError {
        Button {
            guard let athleteId = athlete.id else { return }
            mindsetLoadError = false
            Task {
                do {
                    mindsetProfile = try await RunnerMindsetService.fetchProfile(athleteId: athleteId)
                } catch {
                    mindsetLoadError = true
                }
            }
        } label: {
            HStack {
                Text("Couldn't load · tap to retry")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppTheme.Colors.DarkMode.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
    } else if let profile = mindsetProfile {
        Button { showingEditMindset = true } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.runnerIdentity)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(profile.identitySummary)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(AppTheme.Colors.DarkMode.textSecondary)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppTheme.Colors.warmAmber.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.Colors.warmAmber.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
    } else {
        Button { showingEditMindset = true } label: {
            HStack {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.warmAmber)
                Text("Set your running mindset")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(AppTheme.Colors.warmAmber)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppTheme.Colors.DarkMode.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 4: Add milestones section (after identity card, before LIFETIME)**

Insert this block directly after the MINDSET section and before `// ── LIFETIME`:

```swift
// ── MILESTONES ─────────────────────────────────────────
if !milestones.isEmpty {
    VStack(alignment: .leading, spacing: 10) {
        EyebrowLabel(text: "MILESTONES")
        VStack(spacing: 0) {
            ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                if index > 0 {
                    Divider().background(Color.white.opacity(0.06))
                }
                MilestoneRow(milestone: milestone)
            }
        }
        .background(AppTheme.Colors.DarkMode.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }
}
```

- [ ] **Step 5: Add Running Mindset row to ACCOUNT section**

In the ACCOUNT `VStack(spacing: 0)`, add the new row as the first item (before `AccountRow(icon: "bolt.fill", ...)`):

```swift
AccountRow(
    icon: "figure.run",
    title: "Running Mindset",
    subtitle: mindsetProfile?.runnerIdentity ?? "Not set"
)
.onTapGesture { showingEditMindset = true }
Divider().background(Color.white.opacity(0.06)).padding(.leading, 64)
```

- [ ] **Step 6: Add .sheet modifier and MilestoneRow struct**

Add the sheet to the `ZStack` or at the end of `body` before the closing brace of the scroll view chain. Append to the `.task` chain:

```swift
.sheet(isPresented: $showingEditMindset) {
    if let athleteId = athlete.id {
        EditRunnerMindsetView(
            athleteId: athleteId,
            existing: mindsetProfile,
            onSave: { newProfile in
                mindsetProfile = newProfile
            }
        )
    }
}
```

Add `MilestoneRow` as a private struct at the bottom of `AthleteView.swift`, after `PersonalBestRow`:

```swift
// MARK: - Milestone Row

private struct MilestoneRow: View {
    let milestone: RunnerIdentityMilestone

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(milestone.earned
                          ? AppTheme.Colors.warmAmber
                          : Color.white.opacity(0.06))
                    .frame(width: 32, height: 32)
                Image(systemName: "medal.fill")
                    .font(.system(size: 13))
                    .foregroundColor(milestone.earned ? .black : AppTheme.Colors.DarkMode.textTertiary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.label)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(milestone.earned ? .white : AppTheme.Colors.DarkMode.textSecondary)
                Text(milestone.description)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
            }
            Spacer()
            if milestone.earned, let date = milestone.earnedAt {
                Text(date, format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Colors.warmAmber)
            } else {
                Text("Not yet")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(AppTheme.Colors.DarkMode.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(minHeight: 56)
        .opacity(milestone.earned ? 1.0 : 0.55)
    }
}
```

- [ ] **Step 7: Commit**

```bash
git add "Runaway iOS/Views/AthleteView.swift"
git commit -m "feat: add mindset identity card, milestones section, and ACCOUNT row to Profile"
```

---

## Task 6: Build verification

**Files:** (no changes — verification only)

- [ ] **Step 1: Build the app target**

```bash
xcodebuild -project "Runaway iOS/Runaway iOS.xcodeproj" \
    -scheme "Runaway iOS" \
    -destination "platform=iOS Simulator,name=iPhone 16" \
    build 2>&1 | tail -30
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: If build fails, address errors in order**

Common issues and fixes:

**`FlowLayout` redeclared**: Remove the second definition — `FlowLayout` should only appear once (in `EditRunnerMindsetView.swift`). References in `OnboardingStepViews.swift` work because they're in the same module.

**`AppTheme.Colors.DarkMode.textSecondary` not found**: Check `Utils/Theme.swift` for the exact property name. It may be `secondaryText` or `textSecondary`. Grep:
```bash
grep -r "textSecondary\|secondaryText" "Runaway iOS/" --include="*.swift" | head -5
```

**`AccountRow` missing `onTapGesture`**: `AccountRow` may already have a tap handler built in. Check its definition and wire the sheet via `onTapGesture` or pass an action closure if the component supports it.

**`async let` closure syntax error**: Swift requires `async let` values to be `async throws` functions, not closures. If the nested closure causes issues, replace the concurrent load with sequential:
```swift
personalBests = (try? await PersonalBestService.shared.recomputeAndSave(athleteId: athleteId)) ?? []
isLoadingPRs = false
mindsetProfile = try? await RunnerMindsetService.fetchProfile(athleteId: athleteId)
if mindsetProfile == nil { mindsetLoadError = true }
milestones = (try? await RunnerMindsetService.fetchMilestones(athleteId: athleteId)) ?? []
```

- [ ] **Step 3: Final commit after any build-fix adjustments**

```bash
git add -u
git commit -m "fix: resolve build errors from Phase 2 mindset UI integration"
```

---

## Self-Review Checklist

**Spec coverage:**
- ✅ `MindsetProfile` and `RunnerIdentityMilestone` models (Task 1)
- ✅ `RunnerMindsetService.fetchProfile` / `saveProfile` / `fetchMilestones` (Task 1)
- ✅ `EditRunnerMindsetView` sheet with WHY I RUN + chip picker, pre-populates existing, save/cancel (Task 2)
- ✅ `RunnerMindsetStepView` in onboarding, 200-char limit, 10-char minimum, max 3 chips, skip link (Task 4)
- ✅ `OnboardingStep.runnerMindset` inserted at position 5, later steps renumbered (Task 3)
- ✅ `OnboardingContainerView` registers new step, `saveMindsetAndAdvance` fire-and-forget (Task 4)
- ✅ Identity card in Profile: amber card when set, prompt when not set, retry row on error (Task 5)
- ✅ Milestones section hidden when empty, shown as list rows with earned disc + date (Task 5)
- ✅ ACCOUNT row "Running Mindset" with identity label subtitle (Task 5)
- ✅ `EditRunnerMindsetView` opened from identity card tap, ACCOUNT row tap, prompt tap (Task 5)
- ✅ `onSave` callback updates `mindsetProfile` in-place (Task 5)
- ✅ Build verification (Task 6)

**No Adlerian naming in iOS**: All file names use "Mindset" / "RunnerIdentity". `adlerian_profile` appears only as a database key string inside `RunnerMindsetService.fetchProfile`.

**Type consistency**: `MindsetProfile` defined in Task 1, used in Tasks 2, 4, 5. `RunnerIdentityMilestone` defined in Task 1, used in Task 5. `FlowLayout` defined once in Task 2, used in Task 4. All consistent.
