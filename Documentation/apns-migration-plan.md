# Native APNs Migration Plan
## Replacing Firebase (FirebaseCore + FirebaseMessaging) with native APNs

**Goal:** Eliminate Firebase entirely, dropping 12+ heavy transitive packages (grpc-binary, abseil-cpp-binary, googleappmeasurement, etc.) totaling hundreds of MB from DerivedData.

**Push notifications will be delivered via Supabase Edge Functions → APNs HTTP/2 API directly.**

---

## Current State

| What | Where |
|------|-------|
| `FirebaseApp.configure()` | `AppDelegate.swift` |
| `Messaging.messaging().delegate = self` | `AppDelegate.swift` |
| `Messaging.messaging().token { token in ... }` | `AppDelegate.swift` — gets FCM token, stores it |
| `Messaging.messaging().apnsToken = deviceToken` | `AppDelegate.swift` — bridges APNs → FCM |
| Push token stored in | `athletes.fcm_token` column (Supabase) |
| Sending pushes | Via FCM HTTP v1 API from Edge Functions |

---

## Target State

| What | Where |
|------|-------|
| `UNUserNotificationCenter` registration | `AppDelegate.swift` (already partially there) |
| APNs device token | Stored in `athletes.apns_token` column |
| Sending pushes | Supabase Edge Function → APNs HTTP/2 API using a p8 key |
| No Firebase | Project has zero Firebase dependencies |

---

## Step 1 — Apple Developer Setup

1. **Create an APNs Auth Key (p8)**
   - Log in to [developer.apple.com](https://developer.apple.com) → Certificates, IDs & Profiles → Keys
   - Create a new key, enable **Apple Push Notifications service (APNs)**
   - Download `AuthKey_XXXXXXXXXX.p8` — **this can only be downloaded once**
   - Note your **Key ID** (10-char) and **Team ID** (from top-right of developer portal)

2. **Enable Push Notifications capability in Xcode**
   - Target → Signing & Capabilities → `+` → Push Notifications
   - Also add Background Modes → check "Remote notifications" (for background delivery)

---

## Step 2 — iOS Code Changes

### AppDelegate.swift

Remove all Firebase imports and calls. The `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` delegate already fires — just store the raw APNs token instead of forwarding to FCM.

```swift
// Remove:
import FirebaseCore
import FirebaseMessaging

// Remove from application(_:didFinishLaunchingWithOptions:):
FirebaseApp.configure()
Messaging.messaging().delegate = self
Messaging.messaging().token { token, error in ... }

// Remove entirely:
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) { ... }
}

// Keep and update:
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    Task { await AthleteService.shared.updateAPNsToken(token) }
}
```

### AthleteService.swift — add `updateAPNsToken`

```swift
func updateAPNsToken(_ token: String) async {
    guard let athleteId = DataManager.shared.athlete?.id else { return }
    try? await supabase
        .from("athletes")
        .update(["apns_token": token])
        .eq("id", value: athleteId)
        .execute()
}
```

---

## Step 3 — Database

Add `apns_token` column to `athletes` table:

```sql
ALTER TABLE athletes ADD COLUMN IF NOT EXISTS apns_token TEXT;
```

Create migration: `runaway-edge/supabase/migrations/YYYYMMDD_add_apns_token.sql`

The existing `fcm_token` column can be left in place until the migration is fully rolled out, then dropped.

---

## Step 4 — Supabase Edge Function: `send-push`

Replace any FCM-based push sending with a direct APNs HTTP/2 call.

APNs requires:
- **JWT bearer token** signed with the p8 key (valid for 1 hour, reusable)
- **HTTP/2** POST to `https://api.push.apple.com/3/device/{device_token}`
- Headers: `apns-topic` (bundle ID), `apns-push-type`, `apns-priority`

Store in Supabase secrets:
```
APNS_KEY_P8      — contents of AuthKey_XXXXXXXXXX.p8 (the private key)
APNS_KEY_ID      — 10-character key ID
APNS_TEAM_ID     — 10-character Apple Team ID
APNS_BUNDLE_ID   — com.jackrudelic.runawayios
```

Edge function skeleton:

```typescript
// send-push/index.ts
import { getSupabaseAdmin } from "../_shared/supabase-client.ts";

const APNS_KEY_P8   = Deno.env.get("APNS_KEY_P8")!;
const APNS_KEY_ID   = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID  = Deno.env.get("APNS_TEAM_ID")!;
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID")!;
const APNS_URL      = "https://api.push.apple.com";

// Sign a JWT for APNs (ES256, valid 60 min)
async function makeApnsJwt(): Promise<string> {
  const header = { alg: "ES256", kid: APNS_KEY_ID };
  const payload = { iss: APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) };
  const encode = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const unsigned = `${encode(header)}.${encode(payload)}`;

  // Import p8 private key
  const pemBody = APNS_KEY_P8.replace(/-----.*?-----/g, "").replace(/\s/g, "");
  const keyData = Uint8Array.from(atob(pemBody), c => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", keyData.buffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false, ["sign"]
  );
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(unsigned)
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  return `${unsigned}.${sigB64}`;
}

async function sendPush(deviceToken: string, title: string, body: string, data?: object) {
  const jwt = await makeApnsJwt();
  const res = await fetch(`${APNS_URL}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": APNS_BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: { alert: { title, body }, sound: "default", badge: 1 },
      ...data,
    }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(`APNs error ${res.status}: ${JSON.stringify(err)}`);
  }
}
```

Any existing Edge Function that calls FCM (`send-alert`, `notify-activity-insert`, etc.) gets updated to call `sendPush()` instead, fetching `apns_token` from `athletes` rather than `fcm_token`.

---

## Step 5 — Remove Firebase from Xcode

After the code changes are done:

1. In Xcode: Project navigator → Package Dependencies → select `firebase-ios-sdk` → remove
2. Delete `GoogleService-Info.plist` from the project (keep a backup copy outside the repo)
3. Verify build succeeds with no Firebase imports

This drops: firebase-ios-sdk, app-check, google-ads-on-device-conversion-ios-sdk, googleappmeasurement, googledatatransport, googleutilities, grpc-binary, gtm-session-fetcher, abseil-cpp-binary, interop-ios-for-google-sdks, leveldb, nanopb, promises, google-ads-on-device-conversion-ios-sdk (~400MB of binaries from DerivedData).

---

## Step 6 — Test Checklist

- [ ] App registers for push notifications on launch (system prompt appears on first run)
- [ ] `didRegisterForRemoteNotificationsWithDeviceToken` fires → token stored in `athletes.apns_token`
- [ ] Trigger a push from Edge Function → notification appears on device/simulator
- [ ] Notification received in foreground (via `UNUserNotificationCenterDelegate`)
- [ ] Notification tapped → app opens to correct screen (via `userNotificationCenter(_:didReceive:)`)
- [ ] Background notification wakes app (if background modes enabled)
- [ ] Build size reduced significantly vs. Firebase baseline

---

## Notes

- The p8 key is **not per-device** — one key covers all devices for the app. Rotate it in Apple Developer portal if compromised.
- APNs JWT tokens are valid for 1 hour. Cache and reuse within an Edge Function invocation; regenerate on the next cold start.
- Sandbox vs. Production: `api.sandbox.push.apple.com` for development/TestFlight, `api.push.apple.com` for production. Use `APNS_PRODUCTION=true` env var to switch.
- If you later want notification topics (e.g. per-athlete channels), look at Supabase Realtime broadcast as an alternative to push for in-app scenarios.
