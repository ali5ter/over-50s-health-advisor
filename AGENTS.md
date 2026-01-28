# AGENTS.md

Last updated: 2026-01-28

## Project Snapshot
- Project: over-50s-health-advisor
- Goal: Define and build a Claude Code Agent that advises a User (50+), with evidence-based guidance on fitness, nutrition, metabolic indicators, and mental/physical health.
- Audience: Primarily Alister (personalized), with a generalized version for any 50+ User.

## Current Requirements (from PRD)
- Provide guidance as a health advisor for 50+ Users, using layperson-friendly language but suitable for clinicians.
- Always remind Users to confirm with real healthcare professionals.
- Use credible, evidence-based sources with citations; no hallucinations.
- Maintain User health context locally in project files; keep it within context limits and notify User if trimming is needed.
- Agent quality standard: clear description, explicit context management, task-specific tools/permissions, subagent use when needed, feedback loop; keep instructions minimal and iterate.
- Deliverables:
  - Single Markdown agent definition.
  - Bash install/reinstall script.
  - Separation of personal data from the agent definition for general use.
  - MD files capturing client context.
  - Public GitHub repo with README and LICENSE.

## Architecture

**User-level scope (default):**
- Agent installed to `~/.claude/agents/over-50s-health-advisor.md`
- Context files in `~/.claude/over-50s-health-advisor/context/`
- Works from any directory
- Implemented: 2026-01-28

**Project-level scope (development):**
- Agent in `.claude/agents/` (gitignored)
- Context files in `context/user/` (gitignored)
- Works only within project directory

## Files
- `PROJECT_REQUIREMENTS_DOCUMENT.md`: Primary PRD.
- `agent/over-50s-health-advisor.md`: Agent definition (source).
- `context/templates/`: Committed context templates (no personal data).
- `context/README.md`: Context usage guidance.
- `install.sh`: Install script (defaults to user scope).
- `README.md`, `LICENSE`, `TESTING.md`: Repo docs.

## Recent Changes (2026-01-28)
- Restructured to user-level scope by default
- Context files now stored in `~/.claude/over-50s-health-advisor/context/`
- Agent works from any directory when installed to user scope
- Install script preserves existing context files on reinstall
- Added evidence source guidelines (reputable .org and .com sites)
- Updated all documentation to reflect new architecture

## Open Questions / Decisions Needed
- None currently.

## Next Step (Proposed)
- Run the tests in `TESTING.md` to verify user-level installation
- Test cross-directory invocation
- Consider creating migration guide for existing users
