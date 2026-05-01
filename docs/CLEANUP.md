# Cleanup Backlog

Issues identified in the May 2026 audit that didn't make the weekend sprint.
Pull from this list at the start of each feature sprint.

## High Priority

- [ ] Singleton DI refactor — 11 singletons with no coordination; introduce a service locator or environment-based injection. High blast radius, separate initiative.
- [ ] N+1 fix in HybridActivityRepository.fullSync() — currently issues individual create/update calls in a loop; needs batch upsert.
- [ ] Consolidate RestDayService + ReadinessService + AdaptiveTrainingAlgorithm recovery logic into a single RecoveryAnalyzer.
- [ ] AthleteService.getAthleteByUserId() and AthleteRepository.getAthlete() are duplicate queries — delete one.
- [ ] DataManager and ActivityStore both cache activities independently with no clear ownership — consolidate.

## Medium Priority

- [ ] SettingsView.swift (1391 lines) — split into ProfileSettingsView, IntegrationSettingsView, GoalSettingsView.
- [ ] PlanView.swift (1093 lines) — extract UpcomingRacesSection, TrainingPlanCard.
- [ ] AnalysisView.swift (1045 lines) — extract 8 nested view builders into separate components.
- [ ] AwardBadgeDesigns.swift (1091 lines) — split by badge state (unlocked/locked/progress).
- [ ] OnboardingStepViews.swift (967 lines) — one file per onboarding step.
- [ ] AwardsService.swift (604 lines) — split into AwardCalculator + MilestoneTracker.
- [ ] ActivityTypeDisc icon/color mapping duplicated in 3+ places — single source of truth.
- [ ] MainActor conflicts in HybridActivityRepository — background fetch modifying @MainActor state.
- [ ] Missing cache invalidation in TrainingPlanService — plan cached with no invalidation on goal change.
- [ ] Store binding callbacks (ActivityStore.onActivitiesChanged + DataManager.setupStoreBindings) may cause double-updates — audit and consolidate.

## Low Priority

- [ ] Sheet state in SettingsView — 4 @State booleans for sheet presentation, should be one enum SheetType.
- [ ] Unused imports — MapKit in ActivityDetailView, Charts in AthleteView.
- [ ] UserSession.shared accessed directly in ActivityStore and AthleteStore — should be injected.
- [ ] Calendar.current.isDate() called per-activity in list loops — cache the calendar call.
- [ ] Test coverage — near zero; start with Services that have pure input/output logic.
- [ ] Documentation gaps in SyncEngine.swift and HybridActivityRepository.

## Notes from Sprint

- SupabaseDecoder.swift was flagged as dead code in the audit but is actively used by OnboardingService, UserService, AthleteService, CommitmentService — NOT dead, keep it.
- LocalActivity is a legitimate 7-field view DTO (not redundant with Activity or SDActivity). Data flow: Supabase JSON → Activity → SDActivity → LocalActivity.
- getActivitiesPaginated and getAllActivitiesByUserComplete were correctly kept (real callers, architectural purpose).

## Rules (established May 2026)

- Files over 400 lines are candidates for splitting before new code is added.
- All print() calls must be wrapped in #if DEBUG at write time.
- When noticing a cleanup opportunity during feature work, add it here instead of fixing mid-task.
- Review this list at the start of each feature sprint.
