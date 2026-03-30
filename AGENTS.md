# AGENTS.md

Last updated: 2026-03-18

## Project Snapshot

- Project: over-50s-health-advisor
- Goal: Define and build a Claude Code Agent that advises a User (50+), with evidence-based guidance on fitness,
  nutrition, metabolic indicators, and mental/physical health.
- Audience: Primarily Alister (personalized), with a generalized version for any 50+ User.

## Current Requirements (from PRD)

- Provide guidance as a health advisor for 50+ Users, using layperson-friendly language but suitable for clinicians.
- Always remind Users to confirm with real healthcare professionals.
- Use credible, evidence-based sources with citations; no hallucinations.
- Maintain User health context locally in project files; keep it within context limits and notify User if trimming is needed.
- Agent quality standard: clear description, explicit context management, task-specific tools/permissions, subagent
  use when needed, feedback loop; keep instructions minimal and iterate.
- Deliverables:
  - Single Markdown agent definition.
  - Bash install/reinstall script.
  - Separation of personal data from the agent definition for general use.
  - MD files capturing client context.
  - Public GitHub repo with README and LICENSE.

## Agent Frontmatter Settings

| Field | Value | Rationale |
| --- | --- | --- |
| `model` | `opus` | Opus 4.6 ($5/$25 per MTok in/out) is ~1.67× more expensive than Sonnet 4.6 ($3/$15). For health guidance where accuracy and careful reasoning matter more than latency, the quality tradeoff is justified. Sonnet remains available as a user override. |
| `permissionMode` | `acceptEdits` | Auto-approves file edits without prompting. Context file writes happen multiple times per session; per-write prompts interrupt the health conversation. Other actions (e.g. shell commands) still require approval. |
| `maxTurns` | `40` | Caps sessions at 40 turns to prevent runaway loops or silent context degradation. Covers thorough consultations; the agent summarizes and invites a new session as the limit approaches. |
| `tools` | `Read, Write, WebSearch, WebFetch` | Minimum required tool set: read/write context files, fetch evidence sources. |
| `disallowedTools` | `Bash, Edit, Glob, Grep, Agent` | Explicitly denies tools the agent does not need. `Bash` would be a security risk given health data context. `Edit` is redundant with `Write` for context files. `Glob`/`Grep` are unnecessary as context file paths are known. `Agent` subagent spawning is not required for this use case. |

## Native Memory Field — Evaluation Decision

**Decision: do not adopt** (`memory` field not added to agent frontmatter).

Evaluated 2026-03-30 against `memory: local` and `memory: user` options.

**Why declined:**

- The existing context file system already provides everything native memory offers, with better structure.
  `initialPrompt` auto-loads all five context files at session start, giving the agent the same
  "injected at session start" benefit without a second storage system.
- User editability is a first principle of this agent. Context files are designed to be read and updated
  by the user directly (health records, lab values, clinician notes). Native memory is primarily
  agent-managed and not intended as a user-editable clinical record.
- A second storage location fragments the health record. Everything must stay in one known, auditable
  place: `~/.claude/over-50s-health-advisor/context/`. Splitting facts across `context/` and
  `agent-memory/` creates an unclear source of truth and raises consistency risk.
- Privacy story stays simple. One directory, user-owned, outside any project scope.

**Revisit if:** Claude Code adds a `memory: user` option that supports fully user-editable entries and
a stable, non-project-scoped path without the 200-line injection limit.

## Minimum CLI Version

The plugin framework (`.claude-plugin/plugin.json`, `/plugin install`) has been present since at least v2.0.73
(December 2025), the oldest release available in the GitHub changelog. `minCliVersion` is set to `"2.0.73"` in
`plugin.json` as a conservative lower bound.

## Architecture

**v3.0 — Claude Code plugin framework (current):**

- Distributed via Claude Code native plugin system
- Install: `/plugin marketplace add ali5ter/claude-plugins` then `/plugin install over-50s-health@ali5ter`
- Agent managed by Claude Code plugin infrastructure
- Context files in `~/.claude/over-50s-health-advisor/context/` (auto-created on first run)
- Works from any directory
- No bash installer or manual file copying required
- Implemented: 2026-03-03

**v2.0 — User-level scope (deprecated):**

- Agent installed to `~/.claude/agents/over-50s-health-advisor.md` via `install.sh` (legacy agent ID: `over-50s-health-advisor`)
- Context files in `~/.claude/over-50s-health-advisor/context/`
- Migrate with `./migrate` then reinstall via plugin commands

## Files

- `PROJECT_REQUIREMENTS_DOCUMENT.md`: Primary PRD.
- `agents/advisor.md`: Agent definition (source).
- `.claude-plugin/plugin.json`: Plugin manifest (name, version, description).
- `context/templates/`: Reference context templates (no personal data).
- `context/README.md`: Context usage guidance.
- `install`: Deprecation notice script (replaced by plugin system).
- `migrate`: Migration script for v2.x users removing old `~/.claude/agents/` file.
- `README.md`, `LICENSE`, `TESTING.md`: Repo docs.

## Recent Changes

### 2026-03-18: Rename to domain:role convention (v3.1.0)

- Plugin name: `over-50s-health-advisor` → `over-50s-health`
- Agent file: `agents/over-50s-health-advisor.md` → `agents/advisor.md`
- Agent ID: `over-50s-health-advisor` → `over-50s-health:advisor`
- Install command: `/plugin install over-50s-health@ali5ter`
- Version bumped to 3.1.0

### 2026-03-18: Migrate to ali5ter/claude-plugins Central Marketplace

- Removed `.claude-plugin/marketplace.json` (superseded by central marketplace)
- Updated all install documentation (AGENTS.md, CLAUDE.md, README.md, `install`, `migrate`) to reference `ali5ter/claude-plugins`
- Canonical install flow: `/plugin marketplace add ali5ter/claude-plugins` then `/plugin install over-50s-health@ali5ter`

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

## Publishing Updates

After bumping the version in `plugin.json` and `agents/advisor.md`, committing, and pushing:

- Run `/plugin marketplace update ali5ter` in Claude Code before installing — the installer
  uses a cached catalog and will not see the new version without an explicit update.

## Next Steps (Optional)

- Continue real-world usage to validate context budget management
- Monitor citation quality across diverse health topics
- Evaluate session note archival strategy for long-term use
