# AGENTS.md

Last updated: 2026-03-03

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

**v3.0 — Claude Code plugin framework (current):**
- Distributed via Claude Code native plugin system
- Install: `/plugin marketplace add ali5ter/claude-plugins` then `/plugin install over-50s-health-advisor@ali5ter`
- Agent managed by Claude Code plugin infrastructure
- Context files in `~/.claude/over-50s-health-advisor/context/` (auto-created on first run)
- Works from any directory
- No bash installer or manual file copying required
- Implemented: 2026-03-03

**v2.0 — User-level scope (deprecated):**
- Agent installed to `~/.claude/agents/over-50s-health-advisor.md` via `install.sh`
- Context files in `~/.claude/over-50s-health-advisor/context/`
- Migrate with `./migrate` then reinstall via plugin commands

## Files
- `PROJECT_REQUIREMENTS_DOCUMENT.md`: Primary PRD.
- `agents/over-50s-health-advisor.md`: Agent definition (source).
- `.claude-plugin/plugin.json`: Plugin manifest (name, version, description).
- `context/templates/`: Reference context templates (no personal data).
- `context/README.md`: Context usage guidance.
- `install`: Deprecation notice script (replaced by plugin system).
- `migrate`: Migration script for v2.x users removing old `~/.claude/agents/` file.
- `README.md`, `LICENSE`, `TESTING.md`: Repo docs.

## Recent Changes

### 2026-03-03: v3.0 Plugin Framework Migration
- Migrated from bash installer to Claude Code native plugin framework
- Added `.claude-plugin/plugin.json`
- Renamed `agent/` → `agents/` (plugin framework convention)
- Agent now self-initializes context files on first run (no separate install step)
- Replaced `install.sh` with `install` deprecation notice script
- Added `migrate` script for v2.x users
- Updated all documentation for plugin-based installation

### 2026-01-31: Testing Complete, Real-World Usage Initiated
- All comprehensive testing completed and passed
- Installation testing verified (user scope, project scope, preservation)
- Cross-directory invocation validated (multiple test locations)
- Agent behavior confirmed (context access, citations, safety disclaimers)
- Documentation coherence validated (all 6 docs checked)
- Git ignore verification passed (user data properly excluded)
- Agent now in active personal use for health planning

### 2026-01-28: v2.0 Restructuring
- Restructured to user-level scope by default
- Context files now stored in `~/.claude/over-50s-health-advisor/context/`
- Agent works from any directory when installed to user scope
- Install script preserves existing context files on reinstall
- Added evidence source guidelines (reputable .org and .com sites)
- Updated all documentation to reflect new architecture

## Current Status
- **Phase**: Complete (v3.0 plugin framework migration finished)
- **In Use**: Agent actively being used for personal health guidance
- **Production Ready**: Plugin-based distribution ready for public release

## Open Questions / Decisions Needed
- Consider tagging v3.0.0 release after validating plugin install flow
- Optional: Create uninstall guidance for plugin removal

## Next Steps (Optional)
- Continue real-world usage to validate context budget management
- Monitor citation quality across diverse health topics
- Evaluate session note archival strategy for long-term use
