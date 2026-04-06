# Security

Threat model and technical controls for Pixel Agents ESP32.

---

## Threat Classification

| Category | Classification |
|----------|---------------|
| Serial/BLE input | **Untrusted** — all values validated and clamped at boundary |
| CLI transcript data | **Untrusted** — formats may change, companion skips unrecognized records |
| User settings (NVS) | **Trusted** — written by firmware only, bounds-checked on read |
| OAuth tokens (macOS) | **Sensitive** — stored in macOS Keychain, auto-refreshed |
| Rate limit cache | **Untrusted** — file may not exist, format undocumented |

---

## Technical Controls

### 1. Input validation at the boundary
Every value arriving from serial or BLE must be validated and clamped before use. Never assign an externally-supplied value without bounds checking. Array indices always guarded: `(val < COUNT) ? ARRAY[val] : fallback`.

### 2. Bounded string formatting
Always `snprintf(buf, sizeof(buf), ...)` for text rendering. Prevents silent overflow if format arguments change.

### 3. No dynamic execution on untrusted data
No `eval`, no format-string injection, no shell execution from serial input. Protocol messages are fixed-format binary with known payload sizes.

### 4. BLE PIN is not encryption
The 4-digit PIN is broadcast in BLE advertising manufacturer data. It provides **device selection** (choosing which CYD to connect to), not security. Any device within BLE range can read the PIN. This is documented and intentional — the threat model assumes a trusted physical environment.

### 5. OAuth token handling (macOS companion)
- Claude Code rate limit cache read from `~/.claude/rate-limits-cache.json` — read-only, no tokens
- Gemini OAuth credentials read from `~/.gemini/oauth_creds.json` — refreshed via Google OAuth2 endpoint
- Cursor auth token extracted from VS Code SQLite database — read-only access
- All tokens stored in macOS Keychain when possible; never written to disk by the companion

### 6. No network calls from firmware
The ESP32 firmware makes zero network calls. All data arrives via serial or BLE from the companion. WiFi is not used in v1. This eliminates remote attack surface on the device.

### 7. Read-only defaults
Companion reads transcripts (read-only), rate limit cache (read-only), Cursor database (immutable URI). The only writes are to the local activity SQLite database and iCloud sync container.

---

## Sensitive Resources

| Resource | Location | Access |
|----------|----------|--------|
| Claude rate limits | `~/.claude/rate-limits-cache.json` | Read-only by companion |
| Gemini OAuth creds | `~/.gemini/oauth_creds.json` | Read by macOS companion for token refresh |
| Cursor auth token | `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb` | Read-only (immutable URI) |
| macOS Keychain | System Keychain | OAuth tokens cached here |
| iCloud container | `~/Library/Mobile Documents/iCloud~com~esison~PixelAgents/` | Activity heatmap JSON sync |
| NVS (ESP32) | On-chip flash | Settings persistence (dog color, flip, sound) |

---

## CI/CD Security

- GitHub Actions release workflow builds firmware and macOS app on tag push
- macOS app signed with Developer ID and notarized by Apple
- Sparkle auto-update uses EdDSA signatures for appcast integrity
- No secrets in firmware binary — all sensitive data lives on the companion side
