# Quality Score

Letter grades (A–F) per domain. Updated when a domain ships or changes significantly.

- **A** — Well-tested, documented, agent-legible, no known debt
- **B** — Solid implementation, minor gaps in testing or documentation
- **C** — Functional but has known issues or missing coverage. Entry required in [tech-debt-tracker](exec-plans/tech-debt-tracker.md)
- **D** — Significant gaps, fragile, or poorly documented. Entry required in tech-debt-tracker
- **F** — Broken or placeholder only

---

## Firmware Domains

| Domain | Grade | Notes |
|--------|-------|-------|
| Rendering Pipeline | B+ | Double-buffered + strip-buffer fallback both stable. No automated tests; hardware-verified. |
| Character State Machine | B | Complex FSM with 8 states, stable across 54 versions. Mini-agents (v0.13.0) added complexity. |
| Serial Protocol | A- | Well-defined binary framing, XOR checksum, 10 message types. Clean state machine. |
| Sprite System | A | Generated from toolchain, validated via HTML tool. Fully deterministic. |
| BLE Transport | B | Lock-free SPSC ring buffer with atomic ordering. PIN pairing, battery service. Audited for concurrency. |
| Touch Input | B | Two drivers (XPT2046/FT6336G) behind `HAS_TOUCH`/`CAP_TOUCH` guards. Hamburger menu works. |
| Status Bar | B | 5 display modes, battery indicator, transport icons. Tightly coupled with renderer. |
| LED Ambient | B+ | PWM (CYD) + NeoPixel (CYD-S3), 5 auto-selected modes. Clean guard-based compilation. |
| Audio / Sound | B | Two I2S backends, 5 clips, table-driven. CYD 8-bit DAC has lower quality (known limitation). |
| Wake Word | B- | ESP-SR WakeNet9, dedicated FreeRTOS task. CYD-S3 only. Limited to "Computer" trigger. |
| Battery Monitor | B | ADC + LiPo curve. CYD-S3 + LILYGO. Simple, stable. |
| Thermal Management | B | Junction temp monitoring, throttling with backlight management. CYD only. |
| Boot Splash | A- | Animated character, version footer, backlight fade. Well-contained module. |

## Companion Domains

| Domain | Grade | Notes |
|--------|-------|-------|
| Python Companion Bridge | B | Watches Claude/Codex/Gemini transcripts. FSEvents on macOS. Three CLI format parsers. |
| macOS Companion App | B | Swift/SwiftUI menu bar app. 48 XCTest tests. Software Display, Sparkle, iCloud sync. |

## Cross-Cutting

| Concern | Grade | Notes |
|---------|-------|-------|
| Documentation | B+ | Comprehensive AGENTS.md harness, subsystem specs, testing checklist, plan history. |
| Build System | A- | 3 PlatformIO environments, GitHub Actions CI/CD, reproducible builds. |
| Testing | C+ | No firmware unit tests. 48 macOS unit tests. Manual QA checklist (31KB). |
| Security | B | Input validation at boundaries, bounded formatting. BLE PIN is not encryption (documented). |

---

*Last updated: 2026-04-06 (harness migration)*
