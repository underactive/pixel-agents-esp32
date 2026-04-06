@AGENTS.md

## Gemini-Specific Guidance

- Use deep thinking for changes touching 3+ domains or requiring architectural decisions
- Read `ARCHITECTURE.md` before making cross-domain modifications
- Check `docs/exec-plans/active/` for in-progress plans before starting new work
- After implementation, run 7 audit subagents in parallel (see `docs/references/audit-checklist.md`)
- Update `docs/QUALITY_SCORE.md` when shipping or significantly changing a domain
- Bump version in all 5 files when releasing (see `docs/references/common-modifications.md`)
