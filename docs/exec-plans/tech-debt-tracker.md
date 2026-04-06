# Tech Debt Tracker

Discovered during tasks — don't fix inline unless trivial. When resolved, move to the "Resolved" section with a reference to the commit or plan.

---

## Active

### Known Limitations

| Title | Domain | Severity | Added | Notes |
|-------|--------|----------|-------|-------|
| Transcript formats not public APIs | Companion Bridge | Medium | 2026-04-06 | Claude Code JSONL, Codex CLI rollout JSONL, and Gemini CLI session JSON formats may change between versions. No mitigation possible — we parse what we can and skip the rest. |
| No WiFi mode | Transport | Low | 2026-04-06 | USB serial or BLE only. WiFi/WebSocket not implemented. |
| No wireless OTA updates | Build System | Low | 2026-04-06 | Must flash via USB. Browser-based flasher available at `tools/firmware_update.html`. |
| ESP32 CYD has no PSRAM | Rendering | Medium | 2026-04-06 | Renderer uses strip-buffer fallback (320x30 bands) or direct-draw. Minor visual artifacts. |
| CYD audio is 8-bit DAC | Audio/Sound | Low | 2026-04-06 | ESP32 internal DAC provides only 8-bit resolution vs 16-bit on CYD-S3 (ES8311). `SOUND_VOLUME_SHIFT` provides software attenuation. |
| CYD uses no-OTA partition | Build System | Low | 2026-04-06 | `huge_app.csv` (3MB app) required for PCM sound data. Wireless OTA would not work on CYD. |
| No firmware unit tests | Testing | Medium | 2026-04-06 | Manual QA checklist only. 48 macOS unit tests exist. |

### Future Enhancements

| Title | Domain | Severity | Added | Notes |
|-------|--------|----------|-------|-------|
| Web config dashboard | Touch Input | Low | 2026-04-06 | ESP32 hosts AP/mDNS page for WiFi creds, dog color, brightness |
| NTP time sync | Status Bar | Low | 2026-04-06 | Accurate clock for uptime and schedule-based night mode |
| Night mode | Rendering | Low | 2026-04-06 | Dimmer palette + reduced backlight on schedule |
| Voice input via mic | Wake Word | Low | 2026-04-06 | Stream mic audio to companion for STT. Requires transport protocol extension. |
| Custom wake word "Hi Jojo" | Wake Word | Low | 2026-04-06 | TFLite model via microWakeWord-Trainer-AppleSilicon |
| Remote status API | Transport | Low | 2026-04-06 | REST endpoint for Home Assistant/Stream Deck |
| Claude Code hook integration | Companion Bridge | Low | 2026-04-06 | Push events via hooks instead of JSONL polling |
| macOS notifications | macOS Companion | Low | 2026-04-06 | Optional alerts for rate limits/usage thresholds |
| macOS global hotkey | macOS Companion | Low | 2026-04-06 | Toggle popover without clicking menu bar |
| Multi-device dashboard | macOS Companion | Low | 2026-04-06 | Unified view for multiple ESP32s |
| Agent activity timeline | Status Bar | Low | 2026-04-06 | Scrolling ticker of recent state transitions |
| Achievement animations | Rendering | Low | 2026-04-06 | Special animations for milestones (100th tool call, etc.) |
| Multiple display support | Transport | Low | 2026-04-06 | Daisy-chain boards for wider scenes |
| Multi-device sync | Transport | Low | 2026-04-06 | Multiple displays showing same scene |
| CYD SD card — screenshots | Screenshot | Low | 2026-04-06 | Save screenshots to SD without companion |
| CYD SD card — custom sprites | Sprite System | Low | 2026-04-06 | Load user sprite sheets from SD at boot |
| CYD SD card — activity logging | Status Bar | Low | 2026-04-06 | Write agent activity to SD for later review |
| CYD SD card — portable config | Touch Input | Low | 2026-04-06 | Store settings as JSON on SD |
| Theme system | Rendering | Low | 2026-04-06 | Swappable color palettes |
| Custom office layouts | Rendering | Low | 2026-04-06 | JSON-defined room layouts via serial |
| Agent name labels | Rendering | Low | 2026-04-06 | Tiny text below characters |
| Statistics overlay | Status Bar | Low | 2026-04-06 | Total tool calls, active time display |
| BLE phone companion | BLE Transport | Low | 2026-04-06 | Phone app forwarding agent state |
| BLE proximity presence | BLE Transport | Low | 2026-04-06 | Auto-dim/sleep based on phone proximity |
| BLE mesh multi-board | BLE Transport | Low | 2026-04-06 | Synchronized animations across boards |
| Pixel weather widget | Rendering | Low | 2026-04-06 | Weather icon in office scene |
| Stream Deck plugin | macOS Companion | Low | 2026-04-06 | Button showing live agent count |
| Home Assistant integration | Transport | Low | 2026-04-06 | MQTT/REST sensor exposure |

---

## Resolved

*(none yet)*
