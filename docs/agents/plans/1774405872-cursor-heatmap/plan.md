# Plan: Cursor Usage Heatmap

## Objective
Add a GitHub-style "AI Line Edits" contribution heatmap to the Cursor tab in the usage stats popover. Uses cursor.com/api/dashboard/get-user-analytics (cookie auth via WKWebView login).

## Changes
- New `CursorHeatmapData.swift` — data model with streak/activity computation
- New `CursorDashboardAuth.swift` — WKWebView auth window with URL bar for cursor.com login
- Modified `CursorUsageFetcher.swift` — added fetchAnalytics() with cookie-based API call
- Modified `UsageStatsView.swift` — added CursorHeatmapView (53-week grid, 3 rows, color legend, stats)
- Modified `BridgeService.swift` — added @Published cursorHeatmapData, authenticateCursorDashboard()
- Modified `MenuBarView.swift` — passes heatmap data and connect action through

## Risks
- cursor.com API is undocumented and may change
- WKWebView cookie auth requires one-time user login; cookies may expire
- Heatmap grid sizing depends on available popover width
