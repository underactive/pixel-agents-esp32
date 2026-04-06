# Audit: Tabbed Usage Stats View

## Files Changed
- `macos/PixelAgents/PixelAgents/Views/UsageStatsView.swift`
- `macos/PixelAgents/PixelAgents/Views/MenuBarView.swift`

---

## 1. QA Audit

- **Q1.** Negative `displayPct` when `showRemaining` is true and `currentPct` > 100 — `100 - currentPct` produces negative Int. Bar width clamped by `max(0, ...)` so no crash, but percentage text would display "-N%". **Severity: Low.** Clamping at calculation site would be clean fix.
- **Q2.** `enabledProviders` recomputed on every render — max 4 entries, trivially cheap. **No issue.**
- **Q3.** "No usage data" text in `UsageStatsView` is unreachable from `MenuBarView` (outer guard hides entire view when all toggles off). Dead code serving as safety net. **Informational.**
- **Q4.** Cursor secondary bar visibility heuristic duplicated between `ProviderTab.miniBars` and `ProviderDetailView`. **Minor DRY concern.**

## 2. Security Audit

- **S1.** No injection, format string, or buffer overflow risks. All text from controlled internal sources.
- **S2.** No memory leaks or underegistered handlers. All modifiers tied to SwiftUI lifecycle.
- **S3.** No hard crash vectors. Optional chaining and `if let` guards throughout.
- **S4.** No sensitive data exposure. Only percentages and countdowns rendered.
- **Clean.** No security vulnerabilities found.

## 3. Interface Contract Audit

- **I1.** Zeroed stats are semantically ambiguous — collapses "no data" and "genuine 0% usage" into same value for Codex/Gemini/Cursor. Claude mitigated by sign-in prompt. **Design observation.**
- **I2.** [FIXED] Fragile sentinel-value equality check for sign-in detection (inline zero-stats literal vs. local variable in different files). Centralized to `UsageStatsData.zero` static constant.
- **I3.** `claudeAuth` nested ObservableObject observation — changes to `claudeAuth.isAuthenticated` may not propagate through `@EnvironmentObject bridge`. **Pre-existing pattern, not introduced by this change.**
- **I4.** `onOpenSettings` optional chaining — "Sign In" button silently no-ops if not wired. Safe in production (wired in AppDelegate). **Informational.**

## 4. State Management Audit

- **SM1.** `@State selectedProvider` correctly scoped as view-local ephemeral state. **No issue.**
- **SM2.** `.onAppear` / `.onChange` correctly handle initial selection and fallback. No race. **No issue.**
- **SM3.** `showRemaining` has clean unidirectional flow from `@AppStorage` through `@Binding`. **No issue.**
- **SM4.** Same sentinel ambiguity as I1/I2. **Covered above.**
- **Clean.** No state management issues found.

## 5. Resource & Concurrency Audit

- **RC1.** No concurrency issues. Pure SwiftUI view structs, all state main-actor-confined.
- **RC2.** No resource lifecycle issues. No file handles, sockets, or unmanaged resources.
- **RC3.** No timing hazards. All UI updates event-driven.
- **Clean.** No issues found.

## 6. Testing Coverage Audit

- **T1.** No View-layer test infrastructure exists in the project. All existing tests are model-only.
- **T2.** `formatMinutes` pure function (3 branches) and `barColor` threshold logic (90%) are straightforward to unit test but currently uncovered. **Pre-existing.**
- **T3.** `enabledProviders` filtering, `selectedProvider` fallback, and Claude sign-in equality check are untested behavioral branches. **Noted for future.**
- **T4.** Cursor dark-mode color override untested. Visual regression risk. **Noted for future.**

## 7. DX & Maintainability Audit

- **D1.** [FIXED] `showRemaining ? 100 - value : value` repeated 9 times. Extracted to `displayPct(_:showRemaining:)` helper.
- **D2.** [FIXED] `UsageBar` is internal visibility but only consumed within `UsageStatsView.swift`. Made `private`.
- **D3.** [FIXED] Zero-stats sentinel duplicated between files (inline literal vs local var). Centralized to `UsageStatsData.zero`.
- **D4.** Magic numbers for font sizes/padding — common SwiftUI idiom. **Accepted as-is.**
- **D5.** `UsageStatsData` doc comment ("from Claude Code rate limits cache") is stale — now carries data from 4 providers. **Outside changed files, noted.**
