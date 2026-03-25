# Plan: Activity Heatmaps for Claude, Codex, and Gemini

## Objective

Add GitHub-style activity heatmaps to the Claude, Codex, and Gemini provider tabs in the macOS menu bar companion app. These heatmaps visualize daily tool call counts over a 53-week rolling window, identical in layout to the existing Cursor heatmap but using each provider's brand color. Since no external API exists for these CLI providers, tool calls are recorded locally in a SQLite database as they are detected from transcript files.

## Changes

### New files
- `macos/PixelAgents/PixelAgents/Model/ActivityHeatmapData.swift` — Data model parallel to `CursorHeatmapData` with days map, streaks, quartile thresholds, `from(rows:)` builder for SQLite data
- `macos/PixelAgents/PixelAgents/Services/ActivityDatabase.swift` — SQLite wrapper at `~/Library/Application Support/com.pixelagents.companion/activity.db`, UPSERT recording, 366-day loading

### Modified files
- `macos/PixelAgents/PixelAgents/Model/AgentState.swift` — Add `heatmapKey` computed property to `TranscriptSource`
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift` — Published heatmap properties, recording hook in `processTranscripts()`, dirty-flag loading in `checkUsageStats()`, startup load
- `macos/PixelAgents/PixelAgents/Views/UsageStatsView.swift` — Extract `HeatmapGridView` from `CursorHeatmapView`, add `ActivityHeatmapView` wrapper, 3 brand-colored palettes, show heatmaps in all provider detail views
- `macos/PixelAgents/PixelAgents/Views/MenuBarView.swift` — Pass `claudeHeatmapData`/`codexHeatmapData`/`geminiHeatmapData` through to `UsageStatsView`

## Dependencies

- Steps 1-3 (model, DB, AgentState) are independent
- Step 4 (BridgeService) depends on 1-3
- Steps 5-6 (UI) depend on 4

## Risks / Open Questions

- **App restart double-counting**: Restarting while a transcript is active re-reads the file from offset 0, over-counting that session. Acceptable for v1 — quartile-based coloring masks minor inflation.
- **Empty on first install**: No backfill from historical transcripts; data accumulates from first app run.
- **Color palette tuning**: Interpolated palettes may need visual adjustment after testing in dark mode.
