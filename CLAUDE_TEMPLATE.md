# CLAUDE.md - [Project Name] Project Context

## Project Overview

**[Project Name]** is [one-sentence description of what this project does, its platform, and primary function].

**Current Version:** X.Y.Z
**Status:** [In development | Alpha | Beta | Production-ready]

---

## Hardware

<!-- Remove this section entirely if this is a software-only project -->

### Microcontroller
- **[MCU name and variant]**
- [Architecture and clock speed]
- [Connectivity (BLE, WiFi, etc.)]
- [Flash and RAM]
- [Power features]

### Components
| Ref | Component | Purpose |
|-----|-----------|---------|
| U1 | [MCU] | [Purpose] |
| ... | ... | ... |

### Pin Assignments
| Pin | Function | Notes |
|-----|----------|-------|
| ... | ... | ... |

---

## Architecture

### Core Files
[Brief description of the architecture style — modular, monolithic, microservices, etc.]

- `[entry_point]` - Entry point: [brief description]
- `[config_file]` - Configuration constants, enums, structs
- `[state_file]` - Mutable state / global state management
- `[settings_file]` - Persistent storage + accessors
<!-- Add one line per core module -->

### Dependencies
- [Dependency 1]
- [Dependency 2]
- [Dependency 3]

### Key Subsystems

<!-- Document each major subsystem. Include enough detail that an AI assistant
     can understand the design intent, constraints, and gotchas without reading
     every source file. Focus on: what it does, how it works, and what NOT to do. -->

#### 1. [Subsystem Name]
- [How it works at a high level]
- [Key design decisions and why]
- [Important constraints or limitations]

#### 2. [Subsystem Name]
- ...

#### 3. Settings / Configuration Storage
<!-- If your project has persistent settings, document the struct and storage mechanism -->
```
[Settings struct or schema here]
```
- Saved to [storage location] via [storage mechanism]
- Default values: [list key defaults]

#### 4. Communication Protocol
<!-- If your project has a config/command protocol, document it here -->
```
[Protocol format examples]
```
- [Transport details]
- [Protocol conventions: prefixes, delimiters, response format]

---

## Build Configuration

<!-- Document non-obvious build tool decisions, loader/plugin configs, and the reasoning
     behind them. "Build Instructions" covers how to run builds; this section covers
     why the build is configured the way it is. -->

### [Build tool / bundler name] Configuration
- **[Config option]** — [what it does and why it's needed]
- **[Config option]** — [what it does and why it's needed]
<!-- Example: runtimeCompiler: true — required for library X which uses string templates -->
<!-- Example: linker script uses custom FLASH origin — board has non-standard memory map -->

### Environment Variables

<!-- Document the env var layering strategy and key variables that control build behavior.
     For embedded: this may be build defines, board variant flags, or preprocessor macros. -->

| Variable | Purpose | Values |
|----------|---------|--------|
| `[VAR_NAME]` | [What it controls] | [Possible values or default] |
| ... | ... | ... |

Environment files / define sources:
- `[file1]` — [which build mode / board variant]
- `[file2]` — [which build mode / board variant]

---

## Code Style

<!-- Document linting, formatting, and style conventions that a contributor needs to match.
     Include tool configs, key rule overrides, and any non-obvious style decisions. -->

- **Linter:** [tool and config] (e.g., ESLint + Airbnb, clang-tidy, clippy)
- **Formatter:** [tool] (e.g., Prettier, clang-format, rustfmt)
- **Key rule overrides:** [list any rules turned off or customized, and why]
- **Indentation:** [spaces/tabs and size]
- **Line length:** [max chars]
- **Line endings:** [LF/CRLF]

---

## External Integrations

<!-- Document third-party services, SDKs, or external dependencies where the integration
     involves configuration, lifecycle management, or hostname/environment gating.
     Distinct from Key Subsystems (code you wrote) — these are services you consume. -->
<!-- For embedded: HAL/SDK versions, cloud services, OTA providers, etc. -->

### [Service Name]
- **What:** [brief description of the service]
- **Loaded via:** [script URL, SDK import, env var, etc.]
- **Lifecycle:** [how it starts, shuts down, restarts — if applicable]
- **Environment/hostname gating:** [which environments or hostnames activate it]
- **Key env vars:** [relevant environment variables]
- **Gotchas:** [non-obvious behavior, ordering dependencies, etc.]

---

## Known Issues / Limitations

1. **[Issue]** - [Brief explanation]
2. **[Issue]** - [Brief explanation]
<!-- Keep this list current. Remove items when fixed, add new ones as discovered. -->

---

## Development Rules

<!-- These rules exist to prevent classes of bugs found during QA.
     Follow them for all new code and modifications.
     Add new rules as new bug classes are discovered. -->

### 1. Validate all external input at the boundary
Every value arriving from an external source (API, serial, BLE, user input) must be validated and clamped to valid bounds before being stored or used. Never assign an externally-supplied value without bounds checking.

### 2. Guard all array-indexed lookups
Any value used as an index into an array must have a bounds check before access: `(val < COUNT) ? ARRAY[val] : fallback`. This is defense-in-depth against corrupt or unvalidated values.

### 3. Reset connection-scoped state on disconnect
Buffers, flags, and session variables that accumulate state during a connection must be reset on disconnect to prevent cross-session corruption.

### 4. Avoid memory-fragmenting patterns in long-running code
<!-- Adapt to your platform: heap fragmentation on embedded, memory leaks in Node, etc. -->
In hot paths or long-lived processes, prefer stack-allocated buffers and fixed-size arrays over dynamic allocation. Reserve dynamic allocation for short-lived, one-shot operations.

### 5. Use symbolic constants, not magic numbers
Never hardcode index values or numeric constants — use named defines or enums. When data structures are reordered, update both the data and all symbolic references together.

### 6. Throttle event-driven output
Any function that sends data in response to frequent events must implement rate limiting or throttling to prevent saturation of output channels.

### 7. Use bounded string formatting
Always use `snprintf(buf, sizeof(buf), ...)` (or language equivalent) instead of unbounded formatting. This prevents silent overflow if format arguments change in the future.

### 8. Report errors, don't silently fail
When input exceeds limits or operations fail, provide actionable error feedback to the caller. Never silently truncate, drop, or ignore errors.

<!-- Add project-specific rules below as bugs are discovered during QA.
     Each rule should reference the class of bug it prevents. -->

---

## Plan Pre-Implementation

Before planning, check `docs/CLAUDE.md/plans/` for prior plans that touched the same areas. Scan the **Files changed** lists in both `implementation.md` and `audit.md` files to find relevant plans without reading every file — then read the full `plan.md` only for matches. This keeps context window usage low while preserving access to project history.

When a plan is finalized and about to be implemented, write the full plan to `docs/CLAUDE.md/plans/{epoch}-{plan_name}/plan.md`, where `{epoch}` is the Unix timestamp at the time of writing and `{plan_name}` is a short kebab-case description of the plan (e.g., `1709142000-add-user-auth/plan.md`).

The epoch prefix ensures chronological ordering — newer plans visibly supersede earlier ones at a glance based on directory name ordering.

The plan document should include:
- **Objective** — what is being implemented and why
- **Changes** — files to modify/create, with descriptions of each change
- **Dependencies** — any prerequisites or ordering constraints between changes
- **Risks / open questions** — anything flagged during planning that needs attention

---

## Plan Post-Implementation

After a plan has been fully implemented, write the completed implementation record to `docs/CLAUDE.md/plans/{epoch}-{plan_name}/implementation.md`, using the same directory as the corresponding `plan.md`.

The implementation document **must** include:
- **Files changed** — list of all files created, modified, or deleted. This section is **required** — it serves as a lightweight index for future planning, allowing prior plans to be found by scanning file lists without reading full plan contents.
- **Summary** — what was actually implemented (noting any deviations from the plan)
- **Verification** — steps taken to verify the implementation is correct (tests run, manual checks, build confirmation)
- **Follow-ups** — any remaining work, known limitations, or future improvements identified during implementation

If the implementation added or changed user-facing behavior (new settings, UI modes, protocol commands, or display changes), add corresponding `- [ ]` test items to `docs/CLAUDE.md/testing-checklist.md`. Each item should describe the expected observable behavior, not the implementation detail.

---

## Post-Implementation Audit

After finishing implementation of a plan, run the following subagents **in parallel** to audit all changed files.

> **Scope directive for all subagents:** Only flag issues in the changed code and its immediate dependents. Do not audit the entire codebase.

> **Output directive:** After all subagents complete, write a single consolidated audit report to `docs/CLAUDE.md/plans/{epoch}-{plan_name}/audit.md`, using the same directory as the corresponding `plan.md`. The audit report **must** include a **Files changed** section listing all files where findings were flagged. This section is **required** — it serves as a lightweight index for future planning, covering files affected by audit findings (including immediate dependents not in the original implementation).

### 1. QA Audit (subagent)
Review changes for:
- **Functional correctness**: broken workflows, missing error/loading states, unreachable code paths, logic that doesn't match spec
- **Edge cases**: empty/null/undefined inputs, zero-length collections, off-by-one errors, race conditions, boundary values (min/max/overflow)
- **Infinite loops**: unbounded `while`/recursive calls, callbacks triggering themselves, retry logic without max attempts or backoff
- **Performance**: unnecessary computation in hot paths, O(n²) or worse in loops over growing data, unthrottled event handlers, expensive operations blocking main thread or interrupt context

### 2. Security Audit (subagent)
Review changes for:
- **Injection / input trust**: unsanitized external input used in commands, queries, or output rendering; format string vulnerabilities; untrusted data used in control flow
- **Overflows**: unbounded buffer writes, unguarded index access, integer overflow/underflow in arithmetic, unchecked size parameters
- **Memory leaks**: allocated resources not freed on all exit paths, event/interrupt handlers not deregistered on cleanup, growing caches or buffers without eviction or bounds
- **Hard crashes**: null/undefined dereferences without guards, unhandled exceptions in async or interrupt context, uncaught error propagation across module boundaries

### 3. Interface Contract Audit (subagent)
Review changes for:
- **Data shape mismatches**: caller assumptions that diverge from actual API/protocol schema, missing fields treated as present, incorrect type coercion or endianness
- **Error handling**: no distinction between recoverable and fatal errors, swallowed failures, missing retry/backoff on transient faults, no timeout or watchdog configuration
- **Auth / privilege flows**: credential or token lifecycle issues, missing permission checks, race conditions during handshake or session refresh
- **Data consistency**: optimistic state updates without rollback on failure, stale cache served after mutation, sequence counters or cursors not invalidated after writes

### 4. State Management Audit (subagent)
Review changes for:
- **Mutation discipline**: shared state modified outside designated update paths, state transitions that skip validation, side effects hidden inside getters or read operations
- **Reactivity / observation pitfalls**: mutable updates that bypass change detection or notification mechanisms, deeply nested state triggering unnecessary cascading updates
- **Data flow**: excessive pass-through of context across layers where a shared store or service belongs, sibling modules communicating via parent state mutation, event/signal spaghetti without cleanup
- **Sync issues**: local copies shadowing canonical state, multiple sources of truth for the same entity, concurrent writers without arbitration (locks, atomics, or message ordering)

### 5. Resource & Concurrency Audit (subagent)
Review changes for:
- **Concurrency**: data races on shared memory, missing locks/mutexes/atomics around critical sections, deadlock potential from lock ordering, priority inversion in RTOS or threaded contexts
- **Resource lifecycle**: file handles, sockets, DMA channels, or peripherals not released on error paths; double-free or use-after-free; resource exhaustion under sustained load
- **Timing**: assumptions about execution order without synchronization, spin-waits without yield or timeout, interrupt latency not accounted for in real-time constraints
- **Power & hardware**: peripherals left in active state after use, missing clock gating or sleep transitions, watchdog not fed on long operations, register access without volatile or memory barriers

### 6. Testing Coverage Audit (subagent)
Review changes for:
- **Missing tests**: new public functions/modules without corresponding unit tests, modified branching logic without updated assertions, deleted tests not replaced
- **Test quality**: assertions on implementation details instead of behavior, tests coupled to internal structure, mocked so heavily the test proves nothing
- **Integration gaps**: cross-module flows tested only with mocks and never with integration or contract tests, initialization/shutdown sequences untested, error injection paths uncovered
- **Flakiness risks**: tests dependent on timing or sleep, shared mutable state between test cases, non-deterministic data (random IDs, timestamps), hardware-dependent tests without abstraction layer

### 7. DX & Maintainability Audit (subagent)
Review changes for:
- **Readability**: functions exceeding ~50 lines, boolean parameters without named constants, magic numbers/strings without explanation, nested ternaries or conditionals deeper than one level
- **Dead code**: unused includes/imports, unreachable branches behind stale feature flags, commented-out blocks with no context, exported symbols with zero consumers
- **Naming & structure**: inconsistent naming conventions, business/domain logic buried in UI or driver layers, utility functions duplicated across modules
- **Documentation**: public API changes without updated doc comments, non-obvious workarounds missing a `// WHY:` comment, breaking changes without migration notes

---

## Audit Post-Implementation

After audit findings have been addressed, update the `implementation.md` file in the corresponding `docs/CLAUDE.md/plans/{epoch}-{plan_name}/` directory:

1. **Flag fixed items** — In the audit report (`docs/CLAUDE.md/plans/{epoch}-{plan_name}/audit.md`), mark each finding that was fixed with a `[FIXED]` prefix so it is visually distinct from unresolved items.

2. **Append a fixes summary** — Add an `## Audit Fixes` section at the end of `implementation.md` containing:
   - **Fixes applied** — a numbered list of each fix, referencing the audit finding it addresses (e.g., "Fixed unchecked index access flagged by Security Audit §2")
   - **Verification checklist** — a `- [ ]` checkbox list of specific tests or manual checks to confirm each fix is correct (e.g., "Verify bounds check on `configIndex` with out-of-range input returns fallback")

3. **Leave unresolved items as-is** — Any audit findings intentionally deferred or accepted as-is should remain unmarked in the audit report. Add a brief note in the fixes summary explaining why they were not addressed.

4. **Update testing checklist** — If any audit fixes changed user-facing behavior, add corresponding `- [ ]` test items to `docs/CLAUDE.md/testing-checklist.md`. Each item should describe the expected observable behavior, not the implementation detail.

---

## Common Modifications

<!-- Document step-by-step recipes for common changes.
     These save time and prevent mistakes when making routine modifications.
     Keep each recipe as a numbered checklist. -->

### Version bumps
Version string appears in N files:
<!-- List every file that contains the version string -->
1. `[file1]` - [where in the file]
2. `[file2]` - [where in the file]
3. ...

**Keep all version references in sync.** Always bump all files together during any version bump.

### [Common Modification 1: e.g., "Add a new API endpoint"]
1. [Step 1]
2. [Step 2]
3. ...

### [Common Modification 2: e.g., "Add a new config setting"]
1. [Step 1 — define the setting]
2. [Step 2 — set the default]
3. [Step 3 — add validation (use bounded checks)]
4. [Step 4 — add to UI / protocol if applicable]
5. [Step 5 — update any auto-adapting mechanisms like checksums]
<!-- Reference the Development Rules where applicable -->

---

## File Inventory

| File / Directory | Purpose |
|------------------|---------|
| `[entry_point]` | [Purpose] |
| `[config]` | [Purpose] |
| ... | ... |
| `CLAUDE.md` | This file |
| `docs/` | [What's in docs] |
| `docs/CLAUDE.md/plans/` | Plan, implementation, and audit records (epoch-prefixed directories for chronological ordering) |

---

## Build Instructions

### Prerequisites
- [Tool 1 and version]
- [Tool 2 and version]

### Quick Start
```bash
[setup command]    # Install dependencies
[build command]    # Build the project
[run command]      # Run / flash / deploy
```

### Troubleshooting Build
- **"[common error message]"** - [fix]
- **"[common error message]"** - [fix]

---

## Testing

<!-- Link to or describe the testing approach.
     For large checklists, put them in a separate file and link here. -->

See `[path/to/testing-checklist]` for the full QA testing checklist.

---

## Future Improvements

<!-- Track ideas separately from active work.
     For long lists, put them in a separate file and link here. -->

See `[path/to/future-improvements]` for the ideas backlog.

---

## Maintaining This File

<!-- Instructions for keeping CLAUDE.md accurate over time -->

### When to update CLAUDE.md
- **Adding a new subsystem or module** — add it to Architecture and File Inventory
- **Adding a new setting or config field** — update the Settings section and Common Modifications
- **Discovering a new bug class** — add a Development Rule to prevent recurrence
- **Changing the build process** — update Build Instructions and/or Build Configuration
- **Adding/changing env vars or build defines** — update Build Configuration > Environment Variables
- **Changing linting or style rules** — update Code Style
- **Integrating a new third-party service or SDK** — add to External Integrations
- **Bumping the version** — update the version in Project Overview
- **Adding/removing files** — update File Inventory
- **Finding a new limitation** — add to Known Issues

### Supplementary docs
For sections that grow large (display layouts, testing checklists, changelogs), move them to separate files under `docs/` and link from here. This keeps the main CLAUDE.md scannable while preserving detail.

### Future improvements tracking
When a new feature is added and related enhancements or follow-up ideas are suggested but declined, add them as `- [ ]` items to `docs/CLAUDE.md/future-improvements.md`. This preserves good ideas for later without cluttering the current task.

### Version history maintenance
When making changes that are committed to the repository, add a row to the version history table in `docs/CLAUDE.md/version-history.md`. Each entry should include:

- **Ver** — A semantic version identifier (e.g., `v0.1.0`, `v0.2.0`). Follow semver: MAJOR.MINOR.PATCH. Use the most recent entry in the table to determine the next version number.
- **Changes** — A brief summary of what changed.

Append new rows to the bottom of the table. Do not remove or rewrite existing entries.

### Testing checklist maintenance
When adding or modifying user-facing behavior (new settings, UI modes, protocol commands, or display changes), add corresponding `- [ ]` test items to `docs/CLAUDE.md/testing-checklist.md`. Each item should describe the expected observable behavior, not the implementation detail.

### What belongs here vs. in code comments
- **Here:** Architecture decisions, cross-cutting concerns, "how things fit together," gotchas, recipes
- **In code:** Implementation details, function-level docs, inline explanations of tricky logic

---

## Origin

Created with Claude (Anthropic)
