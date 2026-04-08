# Pixel Agents ESP32

A standalone hardware display that renders Claude Code agents as animated 16x24 pixel art characters in a virtual office scene on an ESP32-S3 with a small color TFT, driven by JSONL transcripts from Claude Code CLI via a Python companion bridge.

**Current Version:** 0.14.0
**Status:** In development

---

## Quick Orientation

| I need to... | Start here |
|--------------|------------|
| Understand the system design and data flow | [ARCHITECTURE.md](ARCHITECTURE.md) |
| See hardware targets, pin assignments, board variants | [ARCHITECTURE.md](ARCHITECTURE.md) + [docs/references/hardware.md](docs/references/hardware.md) |
| Read detailed subsystem specs (FSM, protocol, BLE, etc.) | [docs/references/subsystems.md](docs/references/subsystems.md) |
| Understand build config, defines, PlatformIO environments | [ARCHITECTURE.md](ARCHITECTURE.md) § Build Configuration |
| Check external integrations (JSONL, OAuth, rate limits) | [ARCHITECTURE.md](ARCHITECTURE.md) § External Integrations |
| Review security boundaries and threat model | [docs/SECURITY.md](docs/SECURITY.md) |
| Understand failure modes and system guarantees | [docs/RELIABILITY.md](docs/RELIABILITY.md) |
| Create or review an execution plan | [docs/PLANS.md](docs/PLANS.md) |
| Check for in-progress plans | [docs/exec-plans/active/](docs/exec-plans/active/) |
| Review completed plans | [docs/exec-plans/completed/](docs/exec-plans/completed/) |
| Run the post-implementation audit | [docs/references/audit-checklist.md](docs/references/audit-checklist.md) |
| Run the QA testing checklist | [docs/references/testing-checklist.md](docs/references/testing-checklist.md) |
| Follow a common modification recipe | [docs/references/common-modifications.md](docs/references/common-modifications.md) |
| Check the complete file listing | [docs/references/file-inventory.md](docs/references/file-inventory.md) |
| Review quality scores by domain | [docs/QUALITY_SCORE.md](docs/QUALITY_SCORE.md) |
| See the project evolution timeline | [docs/HISTORY.md](docs/HISTORY.md) |
| Understand display and UI conventions | [docs/DESIGN.md](docs/DESIGN.md) |
| Understand user personas and product principles | [docs/PRODUCT_SENSE.md](docs/PRODUCT_SENSE.md) |
| Review design decisions and core beliefs | [docs/design-docs/](docs/design-docs/) |
| Check tech debt inventory | [docs/exec-plans/tech-debt-tracker.md](docs/exec-plans/tech-debt-tracker.md) |
| Build and flash firmware / start companion | [README.md](README.md) |

---

## Repo Conventions

| Convention | Value |
|------------|-------|
| **Languages** | C++ (firmware, Arduino/ESP-IDF), Python (companion bridge), Swift/SwiftUI (macOS app) |
| **Indentation** | 4 spaces (all languages) |
| **C++ naming** | `camelCase` functions/variables, `PascalCase` classes/enums, `UPPER_SNAKE` constants/defines |
| **Python naming** | PEP 8, `snake_case` |
| **Swift naming** | Standard Swift conventions |
| **Line endings** | LF |
| **Linter** | None configured (manual review) |
| **Formatter** | None configured (manual review) |
| **Test command** | `cd macos/PixelAgents && make test` (macOS); `cd firmware && pio run` (firmware build check) |
| **File size limit** | No hard limit; firmware files kept modular by subsystem |
| **Import rules** | No circular includes. Firmware uses `#include` with guard macros. Dependencies follow layer diagram in ARCHITECTURE.md |

---

## Agent Workflow

When starting a task, follow this process:

### 1. Orient
- Read this file for routing
- Check `docs/exec-plans/active/` for in-progress plans that may conflict
- Read `ARCHITECTURE.md` if the task touches multiple domains

### 2. Research prior work
- Scan `docs/exec-plans/completed/` for prior plans that touched the same files — check **Files changed** lists in `implementation.md` and `audit.md` files to find matches without reading every plan

### 3. Plan (if needed)
- Create a plan for changes touching 3+ domains, requiring architectural decisions, or spanning multiple sessions
- Follow the plan format in [docs/PLANS.md](docs/PLANS.md)
- Write plan to `docs/exec-plans/active/{epoch}-{plan_name}/plan.md`

### 4. Implement
- Follow the core beliefs in [docs/design-docs/core-beliefs.md](docs/design-docs/core-beliefs.md)
- Validate all external input at boundaries
- Guard all array-indexed lookups
- No dynamic allocation in the main loop

### 5. Write implementation record
- Write `implementation.md` in the same plan directory
- **Files changed** section is **required** (serves as a lightweight index for future planning)
- Note any deviations from the plan

### 6. Audit
- Run 7 audit subagents **in parallel** per [docs/references/audit-checklist.md](docs/references/audit-checklist.md)
- Write consolidated `audit.md` in the plan directory
- Fix HIGH/CRITICAL findings before marking complete

### 7. Update documentation
When your changes affect the project:
- **Adding/removing a subsystem** — update `ARCHITECTURE.md` (Core Files + Domains table), `docs/references/subsystems.md`, and `docs/references/file-inventory.md`
- **Adding/changing build defines** — update `ARCHITECTURE.md` § Build Configuration
- **Adding a new board variant** — update `ARCHITECTURE.md` § Hardware, `docs/references/hardware.md`, and follow recipe in `docs/references/common-modifications.md`
- **Adding/removing an integration or dependency** — update `ARCHITECTURE.md` § External Integrations / Dependencies
- **Adding a new protocol message** — update Serial Protocol table in `docs/references/subsystems.md` and follow recipe
- **Adding/removing files** — update `docs/references/file-inventory.md`
- **Adding user-facing behavior** — add `- [ ]` items to `docs/references/testing-checklist.md`
- **Discovering a new bug class** — add a core belief to `docs/design-docs/core-beliefs.md`
- **Finding/resolving a limitation** — update `docs/RELIABILITY.md`
- **Shipping a domain change** — update `docs/QUALITY_SCORE.md`

### 8. Version bump (if releasing)
Bump version in all 5 files — see [docs/references/common-modifications.md](docs/references/common-modifications.md) § Version bumps.

### 9. Move plan to completed
Move plan directory from `docs/exec-plans/active/` to `docs/exec-plans/completed/`.

### 10. Verify
- Confirm firmware builds: `cd firmware && pio run -e cyd-2432s028r`
- Run macOS tests if applicable: `cd macos/PixelAgents && make test`
- Check that no stale documentation references remain

---

## What NOT to Do

- **Don't hardcode values** — use named constants in `config.h`. See core belief #5.
- **Don't dynamically allocate in the main loop** — use fixed-size arrays. See core belief #4.
- **Don't silently swallow errors** — discard with state reset and feedback. See core belief #8.
- **Don't skip input validation** — every serial/BLE value must be bounds-checked. See core belief #1.
- **Don't modify code without reading it first** — understand existing patterns before changing.
- **Don't leave stale documentation** — if the code and docs disagree, fix the docs before the work is considered complete.
- **Don't skip the audit** — run all 7 subagents after every plan implementation.
- **Don't amend prior commits** — create new commits.

---

## Origin

Created with Claude (Anthropic)
