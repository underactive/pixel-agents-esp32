# Audit: Cursor Usage Heatmap (Final)

## Files Changed
- `macos/PixelAgents/PixelAgents/Model/CursorHeatmapData.swift`
- `macos/PixelAgents/PixelAgents/Services/CursorDashboardAuth.swift`
- `macos/PixelAgents/PixelAgents/Services/CursorUsageFetcher.swift`
- `macos/PixelAgents/PixelAgents/Views/UsageStatsView.swift`
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift`
- `macos/PixelAgents/PixelAgents/Views/MenuBarView.swift`

---

## 1. QA Audit

- **Q2.** Threshold bands can collapse with sparse data (e.g., all days with 1 edit → only levels 0 and 4). Accepted — reasonable for new users.
- **[FIXED] Q12.** 3s delayed auth check raced with 10s usage timer sync, causing connect button flash. Replaced with immediate `onHeatmapUpdate` callback.
- **Q10.** Heatmap height uses hardcoded 300 for width calc. Accepted — minor cosmetic difference at 328px.

## 2. Security Audit

- **S1.** Domain suffix matching already fixed in earlier round (exact + subdomain match).
- **S2.** Navigation allowlist includes broad domains (google.com, github.com) for OAuth. Accepted — necessary for social login, cookies are domain-scoped.
- **S3.** Cookie header built without CRLF validation. Accepted — URLSession rejects CRLF in headers.
- No high-severity findings.

## 3. Interface Contract Audit

- **I5/I6.** Dual `needsDashboardAuth` boolean on fetcher and bridge. Accepted — fetcher's flag is internal; view uses `if let heatmap` which takes priority over the connect button.
- **I4.** Cold-start cookie restoration depends on async `markAuthenticated` callback completing before prior termination. Accepted — `onHeatmapUpdate` callback provides immediate propagation if fetch succeeds.
- **I8.** `weeklyPct` field repurposed for Cursor on-demand usage. Accepted — view labels it "Secondary", pre-existing design.
- **I9.** Threshold bands can collapse with sparse data. Same as Q2.
- No critical findings.

## 4. State Management Audit

- **[FIXED] SM1.** Stale `cursorNeedsDashboardAuth` after delayed check. Fixed via `onHeatmapUpdate` callback and clearing flag in `checkUsageStats`.
- **SM2.** `needsDashboardAuth` on fetcher disconnected from `cursorNeedsDashboardAuth` on bridge. Accepted — fetcher's flag is internal; bridge flag is the UI source of truth.
- **SM3.** `cachedToken` never invalidated on external DB change. Accepted — self-corrects on 401.

## 5. Resource & Concurrency Audit

- **RC1.** Dual-path completion callback (closeWindow vs windowWillClose). Already guarded with nil checks. Accepted — correct on current runtime.
- **RC7.** Navigation delegate not explicitly cleared on teardown. Accepted — WKNavigationDelegate is weak.
- No high-severity findings.

## 6. Testing Coverage Audit

- **T1.** No tests for CursorHeatmapData model (pure functions, highest test value). Noted for follow-up.
- **T2.** No tests for parseUsageSummary parsing logic. Noted for follow-up.
- No existing view-layer test infrastructure.

## 7. DX & Maintainability Audit

- **D1.** `authenticate()` is 74 lines. Accepted — single-use window setup, extracting helpers would add indirection.
- **D2.** Duplicated cookie domain filter (3 places). Accepted — low churn risk, only 3 occurrences.
- **D8.** Hardcoded 300 in heatmap height. Same as Q10.
- **D9.** ProviderDetailView repeats UsageBar blocks. Pre-existing — not introduced by this change.
