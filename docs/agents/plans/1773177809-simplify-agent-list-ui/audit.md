# Audit: Simplify Agent List UI

## Files Changed

- `macos/PixelAgents/PixelAgents/Views/AgentListView.swift`
- `macos/PixelAgents/PixelAgents/Services/BridgeService.swift`

## Findings

### QA Audit

| ID | Severity | File | Issue |
|----|----------|------|-------|
| [FIXED] Q1 | Critical | BridgeService.swift:355-360 | Duplicate `Identifiable.id` values in `displayAgents` cause undefined `ForEach` behavior |
| [FIXED] Q2 | Low | BridgeService.swift:27 | Empty initial `displayAgents` causes brief UI flash before first poll |
| [FIXED] Q3 | Low | AgentListView.swift:46-53 | `default` in `stateColor` hides future unhandled cases |
| Q5 | Medium | AgentState.swift:4-23 | `CharState` enum missing `activity = 7` case from firmware (intentional — firmware-only state) |

### Security Audit

| ID | Severity | File | Issue |
|----|----------|------|-------|
| S1 | Medium | SerialTransport.swift:171 | Unbounded read buffer growth (pre-existing) |
| S2 | Medium | SerialTransport.swift:77-79 | `write()` spin-loop without handling `n == 0` (pre-existing) |
| S3 | Low | BridgeService.swift:119 | Strong capture of `self` in background dispatch (pre-existing) |
| S4 | Low | AgentTracker.swift:21 | Agent ID wrapping without collision check (pre-existing) |
| S7 | Low | AgentTracker.swift:31 | Non-atomic guard + force-unwrap pattern (pre-existing) |

### Interface Contract Audit

| ID | Severity | File | Issue |
|----|----------|------|-------|
| [FIXED] IC1 | Low | BridgeService.swift:27 | `displayAgents` starts empty (same as Q2) |
| [FIXED] IC2 | Medium | BridgeService.swift:356-359 | Duplicate `Identifiable.id` (same as Q1) |
| IC3 | Low | AgentTracker.swift:20-21 | `nextId` can exceed firmware MAX_AGENT_ID (pre-existing) |
| IC5 | Low | BridgeService.swift:293-360 | Transport disconnect mid-loop leaves dedup state inconsistent (pre-existing) |
| IC6 | Low | BridgeService.swift:97-103 | `stop()` does not reset session dedup state (pre-existing) |

### State Management Audit

| ID | Severity | File | Issue |
|----|----------|------|-------|
| SM-1 | Medium | BridgeService.swift:299-331 | Copy-then-mutate pattern with manual field copy-back is fragile (pre-existing) |
| SM-2 | Low-Medium | BridgeService.swift:354-360 | `displayAgents` set unconditionally at 4 Hz triggers unnecessary SwiftUI diffs (pre-existing pattern; mitigated by popover-only rendering) |
| SM-4 | Medium | BridgeService.swift:201-205 | `tracker.reset()` never called on reconnect; ghost agents persist 30s (pre-existing) |
| SM-5 | Medium-High | BridgeService.swift:119-121 | Screenshot background thread violates `@MainActor` isolation (pre-existing) |

### Resource & Concurrency Audit

| ID | Severity | File | Issue |
|----|----------|------|-------|
| C1 | Medium | BridgeService.swift:119 | `requestScreenshot()` accesses `@MainActor`-isolated property from background (pre-existing, same as SM-5) |
| C2 | Low | BridgeService.swift:228-230 | `usageFetchTimer` callback missing `@MainActor` hop (pre-existing) |
| R3 | Low | BridgeService.swift:360 | Unconditional `displayAgents` assignment triggers `objectWillChange` every poll (pre-existing) |

### Testing Coverage Audit

| ID | Severity | File | Issue |
|----|----------|------|-------|
| T1 | High | BridgeService.swift:354-360 | 6-slot display array construction logic is untested |
| T3 | High | BridgeService.swift | `BridgeService` has zero test coverage |
| T2 | Medium | AgentListView.swift | No view tests for `AgentListView` / `AgentRow` |

### DX & Maintainability Audit

| ID | Severity | File | Issue |
|----|----------|------|-------|
| [FIXED] DX-A2 | Medium | AgentListView.swift:52 | `default` branch hides unhandled `spawn`/`despawn` (same as Q3) |
| [FIXED] DX-B2 | Low | BridgeService.swift:356 | Magic number `6` for display slot count |
| DX-B1 | Low | BridgeService.swift:79-82 | No-op FSEvents callback with confusing `_ = self` (pre-existing) |
