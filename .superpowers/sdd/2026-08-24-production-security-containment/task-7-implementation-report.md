# Task 7 iOS Security Compatibility Implementation Report

Date: 2026-08-24
Worktree: `/private/tmp/runaway-ios-security-compatibility`
Branch: `codex-ios-security-compatibility`
Task base: `89d938e24550c6594bbc902df1de8fb4bfe7b606`

## Scope completed

- Updated `ensure_athlete_exists` to decode the scalar integer RPC response and made session readiness contingent on a confirmed athlete ID. Setup failures are surfaced with a retry path instead of allowing a partially initialized session into the app.
- Added an authenticated Edge Function client that sends the current Supabase session JWT, handles gateway 401 responses as well as structured function errors, and decodes the secured OAuth initiation response shape.
- Updated Strava and Garmin OAuth initiation to use the secured Edge Functions. Existing callback routing remains in the app; no client-supplied user identity is placed into OAuth state.
- Removed publishable-key-as-bearer behavior from the widget intent. When no safe session token is available, the intent queues an app handoff and truthfully asks the user to open Runaway. Rejected requests remain queued and do not publish optimistic success.
- Added app-side processing for pending widget commitment actions. Pending data is removed only after authenticated persistence succeeds.
- Changed offline sync so failed, invalid, unsupported, and partially completed operations remain queued for retry. A sync date is recorded only when the queue is empty.
- Removed literal `0` personal-best IDs from client upserts and now requires the server-returned record and generated ID.
- Added targeted Run Recording accessibility and safety refinements: Dynamic Type-scaled metrics, VoiceOver labels/state/hints, reduced-motion handling, larger controls, and finish confirmation while preserving the established visual language.

## Changed paths

- `Runaway iOS.xcodeproj/project.pbxproj`
- `Runaway iOS/Models/UserSession.swift`
- `Runaway iOS/Persistence/Sync/SyncEngine.swift`
- `Runaway iOS/Runaway_iOSApp.swift`
- `Runaway iOS/Services/AthleteService.swift`
- `Runaway iOS/Services/AuthenticatedEdgeFunctionClient.swift`
- `Runaway iOS/Services/DailyCommitmentIntentClient.swift`
- `Runaway iOS/Services/GarminService.swift`
- `Runaway iOS/Services/PersonalBestService.swift`
- `Runaway iOS/Services/StravaService.swift`
- `Runaway iOS/Views/ContentView.swift`
- `Runaway iOS/Views/RunRecordingView.swift`
- `Runaway iOS/Views/SettingsView.swift`
- `RunawayWidget/SetDailyCommitmentIntent.swift`
- `Runaway iOS/Runaway iOSTests/AthleteServiceTests.swift`
- `Runaway iOS/Runaway iOSTests/EdgeFunctionClientTests.swift`
- `Runaway iOS/Runaway iOSTests/PersonalBestServiceTests.swift`
- `Runaway iOS/Runaway iOSTests/SetDailyCommitmentIntentTests.swift`
- `Runaway iOS/Runaway iOSTests/SyncEngineTests.swift`
- `Runaway iOS/Runaway iOSTests/UserSessionTests.swift`
- `.superpowers/sdd/2026-08-24-production-security-containment/task-7-implementation-report.md`

## TDD coverage added first

- Scalar `ensure_athlete_exists` decoding.
- Session setup success/failure readiness behavior.
- Structured Edge Function errors and gateway 401 body compatibility.
- OAuth initiation authentication headers and success decoding.
- Widget intent behavior for missing session, rejected persistence, and authenticated success.
- Offline sync partial failure retention and repeated retry retention.
- Personal-best payload omission of client-generated IDs.

## Commands and results

### Environment discovery

Command:

```sh
xcodebuild -project 'Runaway iOS.xcodeproj' -scheme 'Runaway iOS' -showdestinations
```

Result: no eligible simulator destination. Installed simulator runtimes are iOS 18.x, while this Xcode installation exposes the iOS 26.5 SDK and reports destinations as ineligible because iOS 26.5 is not installed.

Commands:

```sh
xcodebuild -showsdks
xcrun simctl list runtimes
```

Result: Xcode SDK is iOS/iOS Simulator 26.5; available simulator runtimes are iOS 18.0 through 18.5. The targeted test invocation exited `70` before running tests because no compatible destination was available.

### Swift compile-through after implementation

Command:

```sh
xcodebuild -project 'Runaway iOS.xcodeproj' -target 'Runaway iOS' -configuration Debug -sdk iphoneos26.5 CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES 'EXCLUDED_SOURCE_FILE_NAMES=*.xcassets LaunchScreen.storyboard' ASSETCATALOG_COMPILER_APPICON_NAME= SYMROOT=/private/tmp/runaway-task7-typecheck3-build OBJROOT=/private/tmp/runaway-task7-typecheck3-obj build
```

Result: the widget and app Swift sources compiled and linked through all Task 7 files with no Task 7 compiler errors. The target later stopped at `ProcessInfoPlistFile` because the gitignored/local `Runaway-iOS-Info.plist` is absent from this isolated worktree. Existing concurrency warnings were emitted.

### Test-bundle compile attempt

Command:

```sh
xcodebuild -project 'Runaway iOS.xcodeproj' -target 'Runaway iOSTests' -configuration Debug -sdk iphoneos26.5 CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES 'EXCLUDED_SOURCE_FILE_NAMES=*.xcassets LaunchScreen.storyboard' ASSETCATALOG_COMPILER_APPICON_NAME= GENERATE_INFOPLIST_FILE=YES INFOPLIST_FILE= SYMROOT=/private/tmp/runaway-task7-tests-build OBJROOT=/private/tmp/runaway-task7-tests-obj build
```

Result: exited `74` before test compilation because the managed filesystem sandbox denied writes to Xcode's SwiftPM and Clang module caches under the user Library/cache directories. The requested elevated rerun was interrupted, so no unrestricted command was allowed to continue.

### Final bounded checkpoint build

Command:

```sh
xcodebuild -project 'Runaway iOS.xcodeproj' -target 'Runaway iOS' -configuration Debug -sdk iphoneos26.5 CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES 'EXCLUDED_SOURCE_FILE_NAMES=*.xcassets LaunchScreen.storyboard' ASSETCATALOG_COMPILER_APPICON_NAME= GENERATE_INFOPLIST_FILE=YES INFOPLIST_FILE= SYMROOT=/private/tmp/runaway-task7-typecheck3-build OBJROOT=/private/tmp/runaway-task7-typecheck3-obj build
```

Result: bounded completion in 1.4 seconds, exit `74`; SwiftPM dependency resolution was blocked before compilation by sandbox-denied writes to `~/.cache/clang/ModuleCache` and `~/Library/Caches/org.swift.swiftpm`. No process remained running afterward.

## Compatibility notes

- Edge requests use the current Supabase access token as `Authorization: Bearer <session JWT>` and continue to send the publishable key only as `apikey`.
- Error decoding accepts the containment handlers' `{success:false,error:string,code?:string}`, structured nested error objects, gateway `{message:...}` responses, and a status-only fallback.
- OAuth initiation consumes `{success:true,authorization_url:string}`. User identity is derived server-side from the JWT; callback routing remains compatible with the existing Runaway URL handling.
- The widget intentionally does not receive or persist a Supabase session token in the app group. Production widget actions therefore use a durable app handoff unless a safe token provider is introduced later.
- Sync operations are acknowledged individually. Successful operations are removed; failures remain with retry metadata, including after partial success.

## Residual risks and blockers

- Unit tests were authored but could not execute because no simulator runtime matches the installed Xcode 26.5 SDK. A compatible iOS 26.5 simulator runtime is required for test execution.
- The managed sandbox blocks Xcode/SwiftPM cache writes during fresh package resolution. An unrestricted local Xcode invocation, or writable redirected package/module caches with existing package checkouts, is required for a fresh test-bundle compile.
- A conventional full app build additionally needs the worktree's local/gitignored `Runaway-iOS-Info.plist` configuration and a matching simulator runtime for asset compilation. No credentials or production configuration were copied into the worktree.
- No live OAuth callback, network persistence, backend deployment, or production action was performed.

## Preserved unrelated worktree changes

The pre-existing changes to `.claude/scheduled_tasks.lock`, `CLAUDE.md`, `Runaway iOS/Services/ActivityInsightService.swift`, older Phase 2/3 plan files, and unrelated `.superpowers` contents were not modified for, staged with, or included in Task 7.

## Findings follow-up: numeric IDs, idempotency, widget draining, and accessibility

Date: 2026-08-24

### Additional implementation

- `SyncEngine` now parses the numeric queue identifiers emitted by `HybridActivityRepository` and resolves activities through `LocalActivityRepository.getActivity(id:)` instead of treating queue IDs as `SDActivity.localId` UUIDs.
- Added `ActivityCreateSyncCoordinator` and an atomic file-backed acknowledgement store. The server response is persisted before local reconciliation. After a local-save failure or restart, the acknowledgement is replayed without another remote request.
- Activity create retries now use the existing numeric activity primary key as the PostgREST upsert conflict key. This makes the remaining server-success/acknowledgement-write interruption retry idempotent and also prevents overlap between Hybrid immediate sync and queued sync from inserting duplicate rows.
- `HybridActivityRepository` queues the saved activity's numeric ID and reconciles immediate-sync responses through the real local repository path instead of attempting a random UUID lookup.
- Widget pending-action drains now run through a main-actor serialized/coalescing coordinator. App appearance/activation requests are coalesced, and a false-to-true `UserSession.isReady` transition triggers a drain immediately.
- `CommitmentManager.loadTodaysCommitment` now returns an explicit success/failure result. Pending widget work is retained without choosing create/update when the load is unconfirmed; successful nil/non-nil results choose create/update respectively.
- Run controls move to a scroll-safe bottom inset. `ViewThatFits` provides horizontal-to-vertical control fallback, accessibility Dynamic Type sizes force vertical controls, and stat values allow adaptive scaling/multiline presentation.

### Additional changed paths

- `Runaway iOS.xcodeproj/project.pbxproj`
- `Runaway iOS/Managers/CommitmentManager.swift`
- `Runaway iOS/Persistence/Sync/ActivitySyncReliability.swift`
- `Runaway iOS/Persistence/Sync/SyncEngine.swift`
- `Runaway iOS/Repositories/HybridActivityRepository.swift`
- `Runaway iOS/Runaway_iOSApp.swift`
- `Runaway iOS/Runaway iOSTests/Task7ReliabilityFollowupTests.swift`
- `Runaway iOS/Services/ActivityService.swift`
- `Runaway iOS/Services/WidgetPendingActionDrainCoordinator.swift`
- `Runaway iOS/Views/RunRecordingLayoutPolicy.swift`
- `Runaway iOS/Views/RunRecordingView.swift`
- `.superpowers/sdd/2026-08-24-production-security-containment/task-7-implementation-report.md`

### Additional tests authored

- Numeric queue ID parsing and lookup through the activity repository seam using the same coordinator invoked by `SyncEngine`.
- Insert acknowledgement persistence across two coordinator/store instances, simulating local-save failure and process restart while asserting only one remote create.
- Readiness false-to-true transition triggering exactly one drain.
- Commitment load failure mapping to retain-pending/no mutation.
- Standard versus accessibility Dynamic Type layout policy.

### Bounded validation command and result

Command:

```sh
env CLANG_MODULE_CACHE_PATH=/private/tmp/runaway-task7-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/runaway-task7-swiftpm-cache XDG_CACHE_HOME=/private/tmp/runaway-task7-xdg-cache xcodebuild -project 'Runaway iOS.xcodeproj' -target 'Runaway iOSTests' -configuration Debug -sdk iphoneos26.5 CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES 'EXCLUDED_SOURCE_FILE_NAMES=*.xcassets LaunchScreen.storyboard' ASSETCATALOG_COMPILER_APPICON_NAME= GENERATE_INFOPLIST_FILE=YES INFOPLIST_FILE= SYMROOT=/private/tmp/runaway-task7-followup-tests-build OBJROOT=/private/tmp/runaway-task7-followup-tests-obj build
```

Result: completed in 5.4 seconds with exit `74` before source compilation. The redirected Clang/SwiftPM module caches were writable, but Xcode's SwiftPM manifest loader still attempted to emit `supabase-swift.dia` under `~/Library/Caches/org.swift.swiftpm`, which the managed sandbox denied. CoreSimulatorService was also unavailable inside the sandbox. No test executed and no source compiler result was produced by this attempt. No further build/test command was run, per the one-bounded-attempt checkpoint.

### Hard Task 8 dependency

The client now prevents duplicate rows for the current contract by using the real numeric activity ID as the upsert conflict key and durably replaying server acknowledgements. The complete cross-installation design still requires Task 8 backend schema support for a user-scoped unique `client_operation_id` (for example, unique on `athlete_id, client_operation_id`) accepted and returned by activity create/upsert. Without that server-owned uniqueness constraint, independently generated client numeric IDs can theoretically collide even though retries of one queued operation are idempotent. No backend file or production system was changed for this follow-up.

## Final findings follow-up: fail-closed idempotency and widget action identity

Date: 2026-08-24

### Implementation corrections

- Changed `SyncEngineError` from file-private to module-internal so the reliability coordinator and compile-focused tests can reference the shared error type cleanly.
- `SyncOperation` now accepts an explicit UUID, and `SyncEngine.queueUpload` persists/returns that UUID. Duplicate queue requests return the already-durable operation ID.
- Queued and immediate Hybrid activity creates share the exact same operation UUID and `ActivityCreateSyncCoordinator` path. Coordinator remote closures now require `(Activity, UUID)` and pass the UUID through the repository and service APIs.
- The legacy remote `createActivity(_:)` implementation now throws `missingClientOperationID`; it cannot silently perform a non-idempotent insert.
- The idempotent payload removes the numeric local `id`, includes `client_operation_id`, and uses PostgREST conflict target `athlete_id,client_operation_id`. The backend therefore generates the activity ID. Missing column/index support causes the request to fail, leaving the acknowledgement absent and queued operation retained.
- Hybrid full-sync discovery no longer inserts pending creates directly. It only queues them with a durable operation ID, preserving the same fail-closed contract.
- Widget pending work is now one encoded immutable `PendingWidgetCommitmentAction` containing `id`, `version`, and `activityType`. Legacy type-only state is migrated on read.
- Successful widget/app processing clears pending data only through `compareAndDelete`, after re-reading and matching the exact action. If a producer replaces the action during a drain, the new action remains and the app coalesces another drain.

### Exact Task 8 migration dependency

The iOS contract now intentionally requires all of the following backend support; it does not fall back when any item is absent:

- Add nullable UUID column `activities.client_operation_id` so existing rows can migrate safely while every new iOS queued/immediate create supplies a value.
- Add a user-scoped unique constraint or partial unique index on `(athlete_id, client_operation_id)`, with the partial predicate `client_operation_id IS NOT NULL` if the column remains nullable for legacy/imported rows.
- Permit PostgREST upsert conflict resolution on the exact target `athlete_id,client_operation_id`.
- Preserve server generation of `activities.id`; the iOS idempotent-create payload deliberately omits `id`.
- Enforce ownership through RLS/server policy: the JWT-authenticated user must own the referenced athlete, inserts must not target another user's `athlete_id`, and conflict updates must not transfer or mutate row ownership. The conflict path must return only the caller-owned existing row.
- Return the canonical activity row after both insert and conflict-update so the client can atomically persist and replay the server acknowledgement.

Until Task 8 applies this migration and ownership policy, queued and immediate activity creates fail safely and remain retryable. No backend file or production system was modified here.

### Tests added or updated

- Coordinator tests now assert the exact operation UUID reaches the remote closure and remains stable across restart acknowledgement replay.
- Added compile-focused signature coverage for explicit `SyncOperation.id`, `ActivityService.createActivity(activity:clientOperationID:)`, and module-visible `SyncEngineError`.
- Existing widget intent tests now assert encoded pending actions instead of the legacy type key.
- Added producer-during-drain coverage proving compare-and-delete cannot remove a newer action.

### Bounded static validation

Command:

```sh
set -o pipefail; xcrun swiftc -parse 'Runaway iOS/Persistence/Models/SyncTypes.swift' 'Runaway iOS/Persistence/Sync/SyncEngine.swift' 'Runaway iOS/Persistence/Sync/ActivitySyncReliability.swift' 'Runaway iOS/Repositories/ActivityRepository.swift' 'Runaway iOS/Repositories/HybridActivityRepository.swift' 'Runaway iOS/Services/ActivityService.swift' 'Runaway iOS/Services/DailyCommitmentIntentClient.swift' 'Runaway iOS/Runaway_iOSApp.swift' 'Runaway iOS/Runaway iOSTests/Task7ReliabilityFollowupTests.swift' 'Runaway iOS/Runaway iOSTests/SetDailyCommitmentIntentTests.swift' && git diff --check && if rg -n 'remoteUpsert: \{ activity in|createActivity\(codableActivity\)|\.upsert\(activity, onConflict: "id"\)' 'Runaway iOS' --glob '*.swift'; then exit 1; else exit 0; fi
```

Result: exit `0` in 3.5 seconds. All changed Swift files passed parser validation, the diff whitespace check passed, and the prohibited non-idempotent call-shape scan returned no matches. No sandbox-blocked `xcodebuild` command was repeated.

## Final P1 closure: update semantics, durable enqueue gate, and file queue

Date: 2026-08-24

### Fixes

- Removed the undefined `created.id` debug reference from Hybrid immediate-create logging.
- `SyncEngine.queueUpload` now accepts and persists the operation type. Hybrid offline updates explicitly enqueue `.update`.
- `SyncEngine` separates create and update execution. Creates continue through the operation-ID idempotent coordinator. Updates resolve the existing local activity by numeric server/Supabase ID, call the remote update API, and reconcile the returned canonical row.
- `ActivityService.updateActivity(activity:)` issues an ownership-scoped update constrained by both `activities.id` and `activities.athlete_id`. Its payload omits `id` and `athlete_id`, preventing primary-key or ownership mutation. It does not use `client_operation_id` create semantics.
- `SupabaseActivityRepository.updateActivity` now calls the real update service instead of returning the input unchanged.
- Hybrid create and update save local data first, then require a durable `SyncEngine` before queueing or launching any immediate network work. Missing sync configuration throws `HybridActivityRepositoryError.syncEngineUnavailable`; no remote create occurs and the local pending record remains.
- `RepositoryFactory` and `DefaultRepositoryProvider` now inject nonoptional `SyncEngine.shared` by default. Optional construction remains only as an explicit test/custom configuration path guarded by the fail-closed check.
- Replaced the cross-process UserDefaults single slot with per-action immutable JSON files at `<app-group>/PendingWidgetCommitments/<action UUID>.json`. Writes are atomic, enumeration drains every file, and deletion verifies and removes only the exact processed file.
- Legacy encoded-action and type-only UserDefaults keys migrate by atomically writing a unique action file before removing the legacy key. Migration failure leaves the legacy value intact.

### Tests added or updated

- Update operation test asserts `.update` is retained and compile-checks the ownership-scoped update service signature.
- Nil SyncEngine test asserts the explicit fail-closed configuration error.
- Widget producer-during-drain test uses two store instances sharing one directory and proves deleting the processed file leaves the newer producer file intact.
- Existing widget success/failure tests now use isolated immutable file queues.

### Bounded parser/static validation

Command:

```sh
set -o pipefail; xcrun swiftc -parse 'Runaway iOS/Persistence/Sync/SyncEngine.swift' 'Runaway iOS/Repositories/ActivityRepository.swift' 'Runaway iOS/Repositories/HybridActivityRepository.swift' 'Runaway iOS/Repositories/RepositoryFactory.swift' 'Runaway iOS/Services/ActivityService.swift' 'Runaway iOS/Services/DailyCommitmentIntentClient.swift' 'Runaway iOS/Runaway_iOSApp.swift' 'Runaway iOS/Runaway iOSTests/SetDailyCommitmentIntentTests.swift' 'Runaway iOS/Runaway iOSTests/Task7ReliabilityFollowupTests.swift' && git diff --check && if rg -n 'created\.id|compareAndDelete|removeObject\(forKey: DailyCommitmentIntentKeys\.pendingActivityType\).*return|\.upsert\([^\n]*onConflict: "id"|case \.create, \.update' 'Runaway iOS/Repositories/HybridActivityRepository.swift' 'Runaway iOS/Persistence/Sync/SyncEngine.swift' 'Runaway iOS/Services/ActivityService.swift' 'Runaway iOS/Services/DailyCommitmentIntentClient.swift' 'Runaway iOS/Runaway_iOSApp.swift'; then exit 1; else exit 0; fi
```

Result: exit `0` in 0.84 seconds with no output. All changed Swift files passed parser validation, `git diff --check` passed, and the prohibited stale debug reference, combined create/update branch, numeric-ID create upsert, and old compare/delete patterns were absent. No `xcodebuild` command was run.

## Final local-row reconciliation and ordered-operation closure

Date: 2026-08-24

### Fixes

- `SyncOperation` now carries an optional stable SwiftData `localRecordID` in addition to its compatibility numeric `entityId`. The optional field remains backward-decodable for existing persisted queues.
- Hybrid create/update resolves and queues the exact `SDActivity.localId`. Immediate create uses the same local UUID.
- Create acknowledgement no longer calls `upsertFromServer`. `LocalActivityRepository.reconcileCreate` finds the exact provisional row by queued `localRecordID` (with numeric fallback only for legacy queue entries), applies canonical server fields, sets the generated `supabaseId`, marks that row synced, and saves the existing context object. It never inserts a second row by returned server ID.
- Create acknowledgement replay after restart uses the same exact-row reconciliation path.
- Queue coalescing now compares operation kind as well as local identity. Repeated creates or repeated updates may coalesce, but an update behind a create is retained as a distinct ordered operation.
- Upload processing tracks failed create identities. A dependent update is not attempted or dropped when its create fails; both remain in order for the next retry.
- Update processing reloads the latest local row by stable UUID. After create acknowledgement, the mapped activity therefore contains the newly assigned server ID and the ownership-scoped update targets that canonical row.
- Hybrid suppresses immediate update while a create for the same local UUID remains pending, preventing a provisional numeric ID from reaching the remote update path.
- Pending widget store instances now have explicit `.producer` and `.appDrain` roles. Producer instances cannot enumerate or migrate legacy state, and the widget producer uses the default producer role.
- Only the app constructs an `.appDrain` store. Legacy type-only migration uses a deterministic UUID/file name, so racing app processes converge on one immutable file rather than producing duplicate actions. Legacy keys are still removed only after atomic file persistence.

### Tests added or updated

- Exact-row acknowledgement test verifies local UUID lookup/reconciliation, generated server ID application, and absence of numeric fallback lookup.
- Sync race regression queues create then update for one local UUID, forces the create to fail, verifies update is neither attempted nor dropped, then verifies retry order is exactly create followed by update.
- Legacy migration test verifies producer enumeration is rejected, the legacy key remains untouched by the producer, and two app drain instances observe one identical migrated file.
- Existing reliability repository spy now implements and records exact local-row reconciliation.

### Bounded parser/static validation

Command:

```sh
set -o pipefail; xcrun swiftc -parse 'Runaway iOS/Persistence/Models/SyncTypes.swift' 'Runaway iOS/Persistence/Sync/SyncEngine.swift' 'Runaway iOS/Persistence/Sync/ActivitySyncReliability.swift' 'Runaway iOS/Repositories/LocalActivityRepository.swift' 'Runaway iOS/Repositories/HybridActivityRepository.swift' 'Runaway iOS/Services/DailyCommitmentIntentClient.swift' 'Runaway iOS/Runaway_iOSApp.swift' 'Runaway iOS/Runaway iOSTests/SyncEngineTests.swift' 'Runaway iOS/Runaway iOSTests/Task7ReliabilityFollowupTests.swift' 'Runaway iOS/Runaway iOSTests/SetDailyCommitmentIntentTests.swift' && git diff --check && if rg -n 'applyServerAcknowledgement|reconcileCreateAcknowledgement[\s\S]{0,200}upsertFromServer|case \.create, \.update|pendingActions\(' 'RunawayWidget/SetDailyCommitmentIntent.swift'; then exit 1; else exit 0; fi
```

Result: exit `0` in 0.79 seconds with no output. All ten changed Swift files passed parser validation, `git diff --check` passed, and the focused acknowledgement-upsert, combined-operation, and widget migration scans found no prohibited matches. No `xcodebuild` command was run.
