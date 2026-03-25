# Implementation: Cursor Usage Heatmap

## Files Changed
- `macos/PixelAgents/PixelAgents/Model/CursorHeatmapData.swift` — NEW: data model with builder from API response, streak computation
- `macos/PixelAgents/PixelAgents/Services/CursorDashboardAuth.swift` — NEW: WKWebView auth window with URL bar, cookie extraction
- `macos/PixelAgents/PixelAgents/Services/CursorUsageFetcher.swift` — Added fetchAnalytics(), dashboardAuth, cookie-based API call
- `macos/PixelAgents/PixelAgents/Views/UsageStatsView.swift` — Added CursorHeatmapView, cursorHeatmap/cursorConnectAction params
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift` — Added @Published cursorHeatmapData, authenticateCursorDashboard()
- `macos/PixelAgents/PixelAgents/Views/MenuBarView.swift` — Passes heatmap data and connect action

## Summary
Implemented cursor.com dashboard analytics integration with WKWebView-based authentication. The heatmap view shows 53 weeks × 3 rows (Mon/Wed/Fri) with 5-level GitHub-style green coloring. Collapsible via disclosure toggle. Shows "Connect Cursor Dashboard" button when not authenticated. API: `POST cursor.com/api/dashboard/get-user-analytics` with `{ startDate, endDate }` epoch ms strings.

## Verification
- `xcodebuild build -scheme PixelAgents -configuration Debug -quiet` — compiles cleanly
- Visual verification pending: auth flow, heatmap rendering, grid sizing

## Audit Fixes

Fixes applied:
1. **Q1/SM1/D1 — Cached thresholds** as stored properties on CursorHeatmapData instead of recomputing O(n log n) per cell
2. **S1 — Domain allowlist** changed from `hasSuffix("cursor.com")` to `host == "cursor.com" || host.hasSuffix(".cursor.com")`
3. **S2 — Cookie domain matching** same fix for cookie filtering
4. **S7 — Force-unwraps** replaced with `guard let` in streak computation and date arithmetic
5. **S8 — URL bar** strips query params that may contain OAuth tokens
6. **S10/RC1 — Double completion** added guards against callback being invoked twice on window close
7. **RC6 — Re-entrant authenticate()** now rejects second call, preserves first caller's completion
8. **Q5/D2 — gridHeight** now computed from shared constants instead of hardcoded magic numbers
9. **D8 — DateFormatter** made static to avoid allocation per call
10. **D15 — weekCount** extracted to named constant
11. **QA12/SM1 — Race condition** replaced 3s delayed auth check with immediate `onHeatmapUpdate` callback from fetcher → bridge. Also clears `cursorNeedsDashboardAuth` in `checkUsageStats` when heatmap data arrives.
12. **Cold-start cookies** — added `HTTPCookieStorage.shared` fallback for WK cookies that don't load on cold start; `markAuthenticated()` copies cookies to shared storage; `UserDefaults` flag persists auth state across launches.
13. **Canvas heatmap** — replaced HStack/ForEach grid with Canvas to prevent horizontal overflow in popover.
14. **7 rows** — changed from 3 rows (M/W/F) to all 7 days (Sun-Sat), with Sunday as first row.

Unresolved:
- Testing coverage for CursorHeatmapData model (should add in follow-up)
- Month label ambiguity (J/M/A for multiple months) — accepted for space constraints
- `needsDashboardAuth` dead state — low impact, not removed to avoid churn

## Follow-ups
- Test actual auth flow with WKWebView → cursor.com login
- Tune heatmap grid height and cell sizing after visual testing
- Handle cookie expiration gracefully (detect 401/307, show reconnect prompt)
- Add unit tests for CursorHeatmapData.from() and streak computation
