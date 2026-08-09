# Cryptaf - Project State

## Current Bug Status
- **Bug**: MANUAL TEST BUG #4 — 2FA CORRECT OTP INTERMITTENTLY REJECTED
- **Status**: **FIX DEPLOYED - AWAITING MANUAL RETEST**
- **Bug**: MANUAL TEST FIX #5 — REMOVE SECURE LINK + FIX PERSONAL CATEGORY CONSISTENCY
- **Bug**: MANUAL TEST BUG #7 — DEAD MAN'S SWITCH CANNOT BE TURNED OFF AFTER DURATION CHANGE
- **Bug**: MANUAL TEST BUG #8 — FALSE DEAD MAN’S SWITCH WARNING AT 48 HOURS
- **Status**: **FIX DEPLOYED - AWAITING MANUAL RETEST**
- **Bug**: MANUAL TEST UI FIX #9 — REMOVE NOMINEE PORTAL FORM FROM OWNER EMERGENCY SCREEN
- **Status**: **FIX DEPLOYED - AWAITING MANUAL RETEST**
- **Bug**: CRITICAL DEAD MAN’S SWITCH FIX #10 — MIGRATE GITHUB EMAIL AUTOMATION TO AUTHORITATIVE DEADLINE
- **Status**: **FIX COMMITTED - AWAITING GITHUB ACTIONS LIVE VERIFICATION**

## Material Changes
- **GitHub Email Automation Migration (Bug #10)**: Migrated `check-emergency-status.js` from deprecated root `lastActiveTime` to the secure `publicMeta/info.emergencyDeadline`. Implemented per-nominee, per-deadline retry and idempotency logic via `notifiedDeadlines` map. Added concurrency lock to `.github/workflows/check-emergency-status.yml` to prevent duplicate overlapping runs. Added comprehensive safe mock tests.
- **Category Consistency**: Centralized file categories in `lib/utils/app_constants.dart` (Documents, Medical, Financial, Legal, Personal). Added Personal to `DashboardScreen` UI and `FileUploadScreen` dropdown.
- **Secure Link**: Removed Secure Link button and click handler completely from `FileViewScreen`. Reflowed Rename, Move, and Delete into a single uniform responsive row using expanded buttons. Left `VaultViewScreen` unmodified as directed.
- `lib/screens/two_factor_verification_screen.dart` and `security_settings_screen.dart`: Prevented rapid overlapping double-submissions by checking `isVerifying`/`isLoading` early in the callback.
- `lib/services/totp_service.dart`: Safely normalized `inputCode` with `.trim()` and enforced strictly numeric 6-character validation to resolve intermittent string comparison failures caused by copy-paste trailing whitespace.
- **Dead Man's Switch - State Truth**: Fixed state bug by relying strictly on `publicMeta/info` as the authoritative source of truth. Removed stale `lastActiveTime` references in `EmergencyScreen` and `checkDeadMansSwitch` cloud function. Enforced secure transitions and re-arming upon returning owner login.
- **Dead Man's Switch - Duration Persistence**: Fixed random `7 Days` overwrite bug. Introduced 4-step secure `setEmergencyDuration` and refactored `updateLastActive` to prevent dirty writes during dropdown selection. Implemented legacy duration migration.
- **Dead Man's Switch - Toggling**: Fixed silent OFF-toggle failure by exempting `emergencyResetAt` from strict equality rule in `firestore.rules` upon deletion. Replicated race-safe 4-step snapshot logic on activation. Introduced loading states and try/catch guards inside `EmergencyScreen` to surface errors gracefully.
- **Dead Man's Switch - 24h Warning**: Fixed a false-positive warning logic in `CountdownDisplay`. Replaced the one-off `NotificationService` invocation with a reactive on-screen warning banner that conditionally renders only when strictly `< 24` hours remaining, and properly unmounts when the deadline is extended or disabled.
- **Dead Man's Switch - Owner UI Cleanup**: Removed the embedded Nominee Access Portal (email form and OTP button) completely from the authenticated owner's `EmergencyScreen`. Re-worded the Security Protocol instructions to correctly reflect dynamic duration configuration and strictly metadata-based key distribution, removing misleading "Transfer keys" language.
- **Firestore Rules**: Secured nominee `files` access by strictly enforcing `emergencyEnabled == true` and server-authoritative `emergencyDeadline`. Allowed safe deletion of deadline markers.

## Verification Evidence (Phase 7 - Live E2E)
1. **Routing Refactor (`lib/main.dart`)**: 
   - Converted `AuthenticationWrapper` to a one-time router that awaits `authStateChanges().first`. This prevents it from aggressively unmounting the `LoginScreen` mid-login.
2. **Error Boundary (`lib/screens/login_screen.dart`)**: 
   - Separated the Auth `try-catch` from the Firestore `try-catch`.
3. **No Changes To**:
   - `crypto_service.dart`, envelope encryption, `firestore.rules`, Dead Man's Switch, nominee logic.

## Verification Evidence (Phase 7 - Live E2E)
- **Live Target**: https://cryptaf-36296.web.app
- **Phase 7 (Production Verification)**: In Progress (Live). Discovered and fixed Phase 7B (startup permission bug). 
  - Fix: Added strict Auth validation gate in `AuthenticationWrapper` using `getIdTokenResult(true)`.
  - Live Testing: 
    - Unauthenticated cold starts reliably load `LoginScreen` without protected Firestore reads.
    - Persisted sessions successfully validate and load `DashboardScreen`.
    - Email/password login is stable.
    - Zero `permission-denied`, `ca9`, `b815`, or `INTERNAL ASSERTION FAILED` errors during live verification.
  - E2E retry to continue (Upload, Offline Key).
- **OWNER LOGIN**: FIXED (Added `activity_logs` Firestore rule)
- **DASHBOARD LOAD**: Awaiting manual retest
- **ENCRYPTED UPLOAD**: FIXED (Wizard Progress and Alignment Corrected)
- **OFFLINE KEY DIALOG**: Awaiting manual retest
- **OFFLINE KEY LENGTH**: Awaiting manual retest
- **OWNER DECRYPTION**: Awaiting manual retest
- **RAW DEK STORED**: NO
- **OFFLINE KEY STORED**: NO
- **ownerWrappedDEK**: ABSENT
- **nomineeWrappedDEK**: ABSENT
- **UNAUTHORIZED NOMINEE**: BLOCKED
- **PRE-DEADLINE AUTHORIZED NOMINEE**: BLOCKED
- **POST-DEADLINE NOMINEE**: BLOCKED
- **WRONG OFFLINE KEY**: BLOCKED
- **CORRECT OFFLINE KEY DECRYPTION**: BLOCKED
- **DEAD MAN'S SWITCH RESET**: BLOCKED
- **ca9 / b815 occurrences**: 0
- **INTERNAL ASSERTION**: 0
- **UNCAUGHT EXCEPTIONS**: 0
- **flutter test**: PASS
- **Firestore emulator tests**: PASS
- **flutter analyze**: PASS
- **flutter build web**: PASS
- **Firebase deploy**: PASS

## Documentation
- Generated `CRYPTAF_MASTER_HANDOFF.md` to provide an exhaustive technical and functional handoff.
