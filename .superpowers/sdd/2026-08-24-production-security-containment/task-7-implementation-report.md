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
