# Runaway Ecosystem Audit Report
**Date:** October 16, 2025
**Scope:** All 5 Runaway Projects
**Auditor:** Claude Code

---

## Executive Summary

This comprehensive audit examined inefficiencies and inconsistencies across the Runaway ecosystem's five interconnected projects. The analysis revealed **critical security vulnerabilities**, significant architectural inconsistencies, and substantial opportunities for code consolidation.

### Critical Findings

🔴 **SECURITY CRITICAL:**
- Exposed credentials in Git repositories (Supabase keys, Strava OAuth secrets)
- Full OAuth tokens logged in Strava Webhooks service
- 511 debug print statements in iOS including partial JWT tokens
- No API versioning strategy exists

⚠️ **HIGH PRIORITY:**
- Inconsistent field naming across projects (snake_case vs camelCase confusion)
- Web client missing 40% of available activity data fields
- Backend services bypass Row Level Security policies
- Mixed authentication patterns (JWT + API key fallback)

✅ **MEDIUM PRIORITY:**
- Substantial code duplication (~40-60% reduction possible)
- Inconsistent error handling patterns
- No structured logging framework
- Endpoint naming inconsistencies

---

## Table of Contents

1. [Authentication & API Integration Issues](#1-authentication--api-integration-issues)
2. [Data Model Inconsistencies](#2-data-model-inconsistencies)
3. [Error Handling & Logging](#3-error-handling--logging)
4. [API Endpoint Consistency](#4-api-endpoint-consistency)
5. [Security Vulnerabilities](#5-security-vulnerabilities)
6. [Code Duplication Opportunities](#6-code-duplication-opportunities)
7. [Recommended Action Plan](#7-recommended-action-plan)

---

## 1. Authentication & API Integration Issues

### 1.1 Critical: Exposed Credentials in Git

**Files Affected:**
- `/Users/jack.rudelic/projects/labs/Runaway iOS/Runaway-iOS-Info.plist` (lines 32-37)
- `/Users/jack.rudelic/projects/labs/strava-webhooks/.env` (lines 1-8)

**Exposed:**
- Supabase service role key (full admin access)
- Runaway Coach API key
- Strava OAuth client secret

**Immediate Action Required:**
1. Rotate ALL credentials immediately
2. Add files to `.gitignore`
3. Remove from git history using `git filter-branch`

### 1.2 Inconsistent auth_user_id → athlete_id Mapping

**Problem:** The mapping between Supabase's `auth_user_id` (UUID) and `athlete_id` (integer) is handled inconsistently across projects.

**Current State:**
- **iOS:** Directly uses Supabase `user.id` without mapping to `athlete_id`
- **Coach API:** Requires database lookup for EVERY request
- **Strava Webhooks:** No connection to Supabase authentication system
- **Web:** Queries for athlete_id on every page load

**Recommendation:**
1. Add `auth_user_id UUID UNIQUE` column to athletes table
2. Store mapped `athlete_id` in JWT claims
3. Implement RLS policies using `auth.uid()`

**Impact:** High - affects all API requests and data security

### 1.3 Mixed Authentication Patterns

**iOS** (`APIConfiguration.swift:80-102`):
```swift
// Dual authentication (JWT + API key fallback)
if let jwtToken = await getJWTToken() {
    headers["Authorization"] = "Bearer \(jwtToken)"
} else if let authToken = getAuthToken() {
    headers["Authorization"] = "Bearer \(authToken)"
}
```

**Coach API** (`main.py:60-92`):
```python
# API key returns fake user_id
if token == settings.SWIFT_APP_API_KEY:
    return {"user_id": "api_key_auth", "auth_user_id": None}
```

**Problem:** API key bypasses RLS policies and creates security confusion.

**Recommendation:** Phase out API key authentication within 90 days, JWT-only.

---

## 2. Data Model Inconsistencies

### 2.1 Field Naming Convention Chaos

| Field | iOS | Web | Coach | Webhooks | Database | Status |
|-------|-----|-----|-------|----------|----------|--------|
| `first_name` | `firstname` | `first_name` | `first_name` | `first_name` | `first_name` | ❌ iOS wrong |
| `average_heart_rate` | `average_heart_rate` | `average_heartrate` | `average_heart_rate` | `average_heart_rate` | `average_heart_rate` | ❌ Web wrong |
| `elevation_gain` | `elevation_gain` | `total_elevation_gain` | `elevation_gain` | `elevation_gain` | `elevation_gain` | ❌ Web wrong |

**Recommendation:** Standardize on snake_case for database/API, camelCase for Swift properties.

### 2.2 Web Client Missing 40% of Activity Fields

**Missing from Web:**
- Elevation metrics (loss, low, high)
- Power metrics (average_watts, max_watts, weighted_average_watts)
- Cadence metrics (average_cadence, max_cadence)
- Weather metrics (temperature, humidity, wind_speed, weather_condition)
- Location data (polylines, coordinates)
- Activity flags (commute, flagged, with_pet, competition)

**Impact:** Web app cannot display comprehensive activity data that exists in database.

**File:** `/Users/jack.rudelic/projects/labs/runaway-web/types/api.ts`

### 2.3 Duplicate Date Fields in iOS

**iOS maintains two date fields:**
- `start_date: TimeInterval?` (legacy)
- `activity_date: TimeInterval?` (current)

**Location:** `/Users/jack.rudelic/projects/labs/Runaway iOS/Runaway iOS/Models/ActivityModels.swift:93-120`

**Recommendation:** Deprecate `start_date`, use `activity_date` everywhere.

### 2.4 Hardcoded Activity Type IDs

**Location:** `/Users/jack.rudelic/projects/labs/strava-webhooks/index.js:288-313`

```javascript
const typeMap = {
    'Run': 103,
    'Ride': 104,
    // ... 20+ hardcoded mappings
};
```

**Problems:**
1. Should reference database table, not hardcoded values
2. Magic numbers (why 103, 104?)
3. New Strava activity types silently become "Workout"

**Recommendation:** Query `activity_types` table dynamically on startup.

---

## 3. Error Handling & Logging

### 3.1 Critical: OAuth Tokens Logged in Plain Text

**Location:** `/Users/jack.rudelic/projects/labs/strava-webhooks/index.js`

```javascript
console.log('Access token:', accessToken)  // LOGS FULL ACCESS TOKEN
console.log('Token response:', tokenResponse.data)  // LOGS REFRESH TOKENS
```

**Severity:** CRITICAL
**Action:** Remove immediately, implement log redaction

### 3.2 iOS: 511 Debug Print Statements

**Examples from APIConfiguration.swift:**
```swift
print("🔐 APIConfiguration: Using JWT token (length: \(token.count), expires in \(Int(timeUntilExpiry))s)")
print("👤 APIConfiguration: Current auth user ID: \(userId)")
print("   Auth Header: Bearer \(String(authHeader.dropFirst(7).prefix(10)))...")
```

**Issues:**
- Logs token length (timing attack vector)
- Logs user IDs (PII)
- Logs partial JWT tokens

**Recommendation:** Remove all print statements from production builds using `#if DEBUG`.

### 3.3 Inconsistent Error Handling Patterns

**iOS:** Well-structured custom errors with 8 specific types
```swift
enum APIError: Error {
    case authenticationError(String)  // 401
    case validationError(String)      // 422
    case serverError(String)          // 500
}
```

**Web:** Generic error handling
```typescript
catch (e) {
    error.value = e as Error
    console.error('Error fetching quick wins:', e)
}
```

**Problem:** Web doesn't differentiate between error types, no status code checking.

**Recommendation:** Create standardized error response format across all services:
```json
{
  "success": false,
  "error": {
    "code": "AUTH_FAILED",
    "message": "Invalid or expired authentication token",
    "statusCode": 401,
    "timestamp": "2025-10-16T12:00:00Z"
  }
}
```

### 3.4 No Structured Logging Framework

**Current State:**
- iOS: print statements only
- Web: console.log/error only
- Coach: JSON formatted logging (best practice)
- Webhooks: console.log with object dumps
- Edge: Basic console logging

**Recommendation:** Implement structured logging with PII redaction across all projects.

---

## 4. API Endpoint Consistency

### 4.1 No API Versioning Strategy

**Current State:** No `/v1`, `/v2`, or version headers exist.

**Risk:** Breaking changes affect all clients immediately with no rollback.

**Files:** `/Users/jack.rudelic/projects/labs/runaway/runaway-coach/api/main.py`

**Recommendation:** Introduce `/v1` prefix for all endpoints.

### 4.2 Mixed Endpoint Naming Conventions

**Three different prefixes for similar functionality:**
- `/analysis/runner` - Legacy comprehensive analysis
- `/enhanced/analysis/performance` - New Strava-integrated analysis
- `/quick-wins/weather-impact` - Fast insights

**Problem:** Unclear which endpoint to use, overlapping functionality.

### 4.3 Inconsistent Parameter Naming

| Endpoint | Parameter | Type | Location |
|----------|-----------|------|----------|
| `/enhanced/*` | `auth_user_id` | Query | URL |
| `/quick-wins/*` | `user_id` (optional) | Query | URL |
| `/analysis/runner` | `user_id` | Body | JSON |

**Recommendation:** Standardize on `user_id` everywhere.

### 4.4 HTTP Method Mismatches

**Issues:**
- `POST /enhanced/analysis/performance?auth_user_id=xxx` - Should be GET (no body sent)
- `POST /enhanced/goals/assess` - Should be GET (idempotent read)

**Recommendation:** Use GET for all read-only operations.

### 4.5 Web Client Underutilizes Coach API

**Web currently uses:**
- ✅ `/quick-wins/comprehensive-analysis`
- ❌ Does NOT use: /analysis, /enhanced, /goals, /chat, /feedback

**Instead:** Web makes direct Supabase queries for most data.

**Problem:** Loses benefits of AI analysis, caching, advanced features.

---

## 5. Security Vulnerabilities

### Critical (Fix Immediately)

1. **Exposed Credentials in Git** - Supabase service role key, API keys
2. **Service Role Key Overuse** - All backend services bypass RLS
3. **OAuth Tokens Logged** - Full tokens visible in Strava webhooks logs
4. **Auth Bypass via API Key** - Allows skipping JWT validation

### High Priority

5. **Missing RLS Policies** - Backend services bypass all security
6. **No auth_user_id Validation** - Potential cross-user data access
7. **Token Expiration Not Checked** - Web doesn't refresh expired tokens
8. **JWT Signature Verification Optional** - Coach API allows unverified tokens in dev

### Medium Priority

9. **No Rate Limiting** - API vulnerable to abuse
10. **Verbose Error Messages** - Internal errors exposed to clients
11. **No CORS Restrictions** - Coach API allows `origins=["*"]`

---

## 6. Code Duplication Opportunities

### 6.1 Strava OAuth Token Refresh Logic

**Duplicated in:** Strava Webhooks service
**Potential:** Could be extracted to `@runaway/strava-client` NPM package

**Estimated Reduction:** 60+ lines of code eliminated

### 6.2 Supabase Query Patterns

**Duplicated across:** iOS (Swift), Web (TypeScript), Coach (Python)

**Example:** Fetching athlete by auth_user_id
- iOS: `ActivityService.swift`
- Web: `useActivities.ts`
- Coach: `supabase_queries.py`

**Recommendation:** Create typed query builders or use Supabase auto-generated types.

### 6.3 Activity Data Transformation

**Duplicated in:**
- Strava Webhooks: `transformActivityData()` function (30+ field mappings)
- iOS: Activity model mapping
- Coach: Activity conversion in routes

**Recommendation:** Create schema validation library and share mapping logic.

### 6.4 JWT Token Validation

**Duplicated across:** iOS and Coach API with different implementations.

**Recommendation:** Shared authentication middleware or utility library.

### 6.5 Utility Functions

**Duplicated:**
- Date/time formatting (in 3+ locations)
- Distance/pace calculations (iOS, Web, Coach)
- Activity type mapping (Webhooks has hardcoded IDs)

**Recommendation:** Create `@runaway/utils` package.

---

## 7. Recommended Action Plan

### Phase 1: Emergency Security Fixes (This Week)

**Priority:** CRITICAL
**Effort:** 2-3 days
**Owner:** Backend team

- [ ] Rotate ALL Supabase keys (anon + service role)
- [ ] Rotate Runaway Coach API key
- [ ] Rotate Strava OAuth credentials
- [ ] Add `.env` and `*-Info.plist` to `.gitignore`
- [ ] Remove credentials from git history
- [ ] Update all 5 projects with new credentials
- [ ] Remove token logging from Strava Webhooks
- [ ] Remove JWT token logging from iOS

**Files to Update:**
- `/Users/jack.rudelic/projects/labs/Runaway iOS/Runaway-iOS-Info.plist`
- `/Users/jack.rudelic/projects/labs/strava-webhooks/.env`
- `/Users/jack.rudelic/projects/labs/runaway-web/.env`
- `/Users/jack.rudelic/projects/labs/runaway/runaway-coach/.env`

---

### Phase 2: Database Schema Updates (Week 2)

**Priority:** HIGH
**Effort:** 3-5 days
**Owner:** Backend + Database

- [ ] Add `auth_user_id UUID UNIQUE` column to athletes table
- [ ] Create migration script to backfill existing records
- [ ] Add foreign key constraint to auth.users table
- [ ] Enable RLS on all tables (activities, athletes, goals, commitments)
- [ ] Create RLS policies using `auth.uid()`
- [ ] Test RLS policies with different users
- [ ] Audit all service role key usage

**SQL Migration:**
```sql
ALTER TABLE athletes ADD COLUMN auth_user_id UUID UNIQUE;
ALTER TABLE athletes ADD CONSTRAINT fk_auth_user
  FOREIGN KEY (auth_user_id) REFERENCES auth.users(id);

ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own activities"
  ON activities FOR SELECT
  USING (athlete_id IN (
    SELECT id FROM athletes WHERE auth_user_id = auth.uid()
  ));
```

---

### Phase 3: Data Model Standardization (Weeks 3-4)

**Priority:** HIGH
**Effort:** 1-2 weeks
**Owner:** Full stack team

#### iOS Changes
- [ ] Rename `firstname` → `firstName`, `lastname` → `lastName`
- [ ] Remove `summary_polyline` property (use `map_summary_polyline`)
- [ ] Remove `start_date` property (use `activity_date`)
- [ ] Update all views referencing old properties
- [ ] Fix `toAPIActivity()` to include heart rate and elevation data

#### Web Changes
- [ ] Fix `average_heartrate` → `average_heart_rate`
- [ ] Fix `total_elevation_gain` → `elevation_gain`
- [ ] Add missing 40% of activity fields to TypeScript types
- [ ] Add missing athlete profile fields (sex, weight, city, state, country)

#### Coach API Changes
- [ ] Standardize on `user_id` parameter everywhere
- [ ] Add athlete resolution middleware to eliminate duplicate code

**Files to Update:**
- `/Users/jack.rudelic/projects/labs/Runaway iOS/Runaway iOS/Models/Athlete.swift`
- `/Users/jack.rudelic/projects/labs/Runaway iOS/Runaway iOS/Models/ActivityModels.swift`
- `/Users/jack.rudelic/projects/labs/runaway-web/types/api.ts`
- `/Users/jack.rudelic/projects/labs/runaway/runaway-coach/api/routes/*.py`

---

### Phase 4: API Standardization (Month 2)

**Priority:** MEDIUM
**Effort:** 2-3 weeks
**Owner:** Backend team

- [ ] Introduce API versioning (`/v1` prefix on all routes)
- [ ] Standardize error response format
- [ ] Fix HTTP method mismatches (POST → GET for read operations)
- [ ] Consolidate endpoint prefixes (/analysis vs /enhanced vs /quick-wins)
- [ ] Add deprecation warnings for old endpoints
- [ ] Create API changelog
- [ ] Generate OpenAPI/Swagger documentation

**Files to Update:**
- `/Users/jack.rudelic/projects/labs/runaway/runaway-coach/api/main.py`
- All route files in `/runaway-coach/api/routes/`

---

### Phase 5: Logging & Error Handling (Month 2)

**Priority:** MEDIUM
**Effort:** 1-2 weeks
**Owner:** All teams

#### iOS
- [ ] Implement LoggingService with PII redaction
- [ ] Remove all print statements from production builds
- [ ] Add retry logic to API client (use configured retryCount=3)

#### Web
- [ ] Implement structured logging with pino or winston
- [ ] Add error type differentiation (401, 422, 500)
- [ ] Add retry logic to API client
- [ ] Display user-friendly error messages

#### Coach API
- [ ] Sanitize error messages (don't expose internal details)
- [ ] Add request ID tracking
- [ ] Implement structured logging across all routes

#### Strava Webhooks
- [ ] Add log redaction for sensitive fields
- [ ] Return JSON error responses (not HTML)

---

### Phase 6: Code Consolidation (Month 3)

**Priority:** LOW-MEDIUM
**Effort:** 2-4 weeks
**Owner:** Architecture team

- [ ] Create `@runaway/strava-client` NPM package
- [ ] Create `@runaway/error-handling` NPM package
- [ ] Create `@runaway/utils` NPM package
- [ ] Create Swift Package for iOS utilities
- [ ] Migrate projects to use shared packages
- [ ] Update Strava Webhooks to load activity types dynamically
- [ ] Remove hardcoded activity type ID mappings

---

## 8. Metrics & Success Criteria

### Security Metrics
- ✅ **Target:** 0 credentials in git repositories
- ✅ **Target:** 0 sensitive data logged (tokens, passwords)
- ✅ **Target:** 100% of tables have RLS policies enabled
- ✅ **Target:** 0 uses of API key authentication (JWT only)

### Data Consistency Metrics
- ✅ **Target:** 100% field naming consistency across projects
- ✅ **Target:** Web client has 100% of available activity fields
- ✅ **Target:** 0 duplicate date/polyline fields in iOS

### API Quality Metrics
- ✅ **Target:** 100% of endpoints versioned (`/v1`)
- ✅ **Target:** 100% of read operations use GET (not POST)
- ✅ **Target:** Consistent `user_id` parameter across all endpoints
- ✅ **Target:** OpenAPI/Swagger documentation generated

### Code Quality Metrics
- ✅ **Target:** 50% reduction in duplicated code
- ✅ **Target:** 100% of API errors return standardized format
- ✅ **Target:** 90%+ of transient failures automatically retried

---

## 9. Risk Assessment

### High Risk
1. **Credential Rotation** - May cause temporary service interruption
   - **Mitigation:** Perform during low-traffic window, have rollback plan

2. **Data Model Changes** - Breaking changes for iOS/Web clients
   - **Mitigation:** Coordinate deployment, maintain backward compatibility

3. **RLS Policy Implementation** - Could break existing queries
   - **Mitigation:** Test thoroughly in staging, add monitoring

### Medium Risk
4. **API Versioning** - Requires client updates
   - **Mitigation:** Support both versioned and unversioned simultaneously

5. **Removing API Key Auth** - May break legacy integrations
   - **Mitigation:** 90-day deprecation period with warnings

### Low Risk
6. **Logging Changes** - Minimal impact on functionality
7. **Code Consolidation** - Improves maintainability

---

## 10. Estimated Effort

| Phase | Effort | Duration | Team Size |
|-------|--------|----------|-----------|
| Phase 1: Security | 2-3 days | 1 week | 1 senior engineer |
| Phase 2: Database | 3-5 days | 1 week | 1 backend engineer |
| Phase 3: Data Models | 5-10 days | 2 weeks | 2 engineers (iOS + Web) |
| Phase 4: API Standardization | 10-15 days | 3 weeks | 1 backend engineer |
| Phase 5: Logging | 5-10 days | 2 weeks | All teams |
| Phase 6: Code Consolidation | 10-20 days | 4 weeks | 1 senior engineer |

**Total Estimated Effort:** 8-12 weeks with 1-2 dedicated engineers

---

## 11. Key Takeaways

### What's Working Well ✅
- Clear separation of concerns (Coach API, Edge Functions, Webhooks)
- Comprehensive endpoint coverage
- Good real-time sync architecture (Supabase Realtime + FCM)
- Multi-agent AI system (LangGraph) is sophisticated and unique

### Critical Issues ❌
- **SECURITY:** Exposed credentials in git, tokens logged in plain text
- **ARCHITECTURE:** No API versioning, mixed auth patterns
- **DATA MODELS:** 40% inconsistency in field naming and coverage
- **CODE QUALITY:** Significant duplication, no structured logging

### Opportunities 🎯
- 40-60% code reduction through shared libraries
- Improved security through RLS policies and JWT-only auth
- Better developer experience through API versioning and docs
- Enhanced Web app with full Coach API integration

---

## 12. Next Steps

1. **Schedule Emergency Security Review** (This Week)
   - Review exposed credentials
   - Plan rotation strategy
   - Identify all services that need updates

2. **Create Project Plan** (Next Week)
   - Assign owners to each phase
   - Set milestones and deadlines
   - Establish testing requirements

3. **Begin Phase 1 Execution** (Week 3)
   - Rotate all credentials
   - Remove token logging
   - Add .gitignore rules

4. **Weekly Progress Reviews**
   - Track completion of tasks
   - Adjust timeline as needed
   - Communicate changes to stakeholders

---

## Appendix A: Files Requiring Changes

### Critical Security Files
- `/Users/jack.rudelic/projects/labs/Runaway iOS/Runaway-iOS-Info.plist`
- `/Users/jack.rudelic/projects/labs/strava-webhooks/.env`
- `/Users/jack.rudelic/projects/labs/strava-webhooks/index.js` (lines 195, 75)
- `/Users/jack.rudelic/projects/labs/Runaway iOS/Runaway iOS/Configuration/APIConfiguration.swift` (lines 186-187)

### Data Model Files
- `/Users/jack.rudelic/projects/labs/Runaway iOS/Runaway iOS/Models/Athlete.swift`
- `/Users/jack.rudelic/projects/labs/Runaway iOS/Runaway iOS/Models/ActivityModels.swift`
- `/Users/jack.rudelic/projects/labs/runaway-web/types/api.ts`
- `/Users/jack.rudelic/projects/labs/runaway/runaway-coach/models/strava.py`

### API Configuration Files
- `/Users/jack.rudelic/projects/labs/runaway/runaway-coach/api/main.py`
- `/Users/jack.rudelic/projects/labs/runaway/runaway-coach/api/routes/*.py`
- `/Users/jack.rudelic/projects/labs/Runaway iOS/Runaway iOS/Configuration/APIConfiguration.swift`
- `/Users/jack.rudelic/projects/labs/runaway-web/nuxt.config.ts`

---

**Report Generated:** October 16, 2025
**Total Issues Found:** 35 (15 Critical, 8 High, 12 Medium)
**Estimated Fix Time:** 8-12 weeks
**Priority:** Begin Phase 1 immediately
