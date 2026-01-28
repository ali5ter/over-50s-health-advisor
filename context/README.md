# Context Files

The over-50s-health-advisor agent uses local Markdown files to maintain your health context, preferences, and session history. This approach keeps your personal health information private and under your control.

## Architecture

### Templates (This Repository)

This repository contains template files in `context/templates/`:
- `INITIAL_USER_INFORMATION.md`
- `CLIENT_HEALTH_CONTEXT.md`
- `CLIENT_PREFERENCES.md`
- `SESSION_NOTES.md`
- `SOURCES.md`

These templates provide structure and examples but contain no real user data.

### User Context Files

When you install the agent with `./install.sh` (user scope), your personal context files are created at:

```
~/.claude/over-50s-health-advisor/context/
├── INITIAL_USER_INFORMATION.md
├── CLIENT_HEALTH_CONTEXT.md
├── CLIENT_PREFERENCES.md
├── SESSION_NOTES.md
└── SOURCES.md
```

These files contain your actual health information and are **never committed to version control**.

## Context File Descriptions

### INITIAL_USER_INFORMATION.md
Basic demographic and goal information:
- Age, sex, primary goals
- Current activity level
- Time and equipment availability
- Initial questions or concerns

### CLIENT_HEALTH_CONTEXT.md
Medical and health history:
- Conditions, medications, surgeries
- Injuries, limitations, contraindications
- Recent lab results or trends
- Healthcare provider information

### CLIENT_PREFERENCES.md
Your preferences for guidance:
- Preferred units (imperial/metric)
- Dietary preferences or restrictions
- Exercise preferences
- Communication style preferences

### SESSION_NOTES.md
Chronological log of interactions:
- Date-stamped session summaries
- Key decisions or plans made
- Progress updates
- Questions for follow-up

### SOURCES.md
Curated list of evidence-based resources:
- High-quality sources the agent has cited
- Your own research findings
- Clinician-provided resources

## Required vs Optional Context

**Required** (minimum for personalized guidance):
- `INITIAL_USER_INFORMATION.md`
- `CLIENT_PREFERENCES.md`

**Optional** but strongly recommended:
- `CLIENT_HEALTH_CONTEXT.md`
- `SESSION_NOTES.md`
- `SOURCES.md`

## Privacy and Data Management

- All context files are stored locally on your machine
- Files are in plain Markdown format (readable, editable with any text editor)
- You have full control to view, edit, or delete any information
- No data is sent to external services except when the agent performs web searches (which do not include your context files)
- The agent only accesses these files when invoked

## Context Budget Management

The agent aims to keep total context under 2,500 words to ensure efficient processing. The agent will:
- Monitor total word count across all context files
- Suggest archiving older session notes when approaching limits
- Always request your approval before pruning or archiving data

## Artifact Ingestion

You can provide artifacts (CSV files, PDFs, lab reports) for the agent to analyze. The agent will:
- Ask for consent before extracting and storing summaries
- Store only relevant, minimal data in context files
- Reference the artifact and extraction date in `SESSION_NOTES.md` or `CLIENT_HEALTH_CONTEXT.md`
- Not store the original artifact (you maintain that separately)

## Editing Context Files

You can edit context files directly with any text editor. The agent treats your edits as authoritative updates. Common workflows:

**Add new health information:**
```bash
nano ~/.claude/over-50s-health-advisor/context/CLIENT_HEALTH_CONTEXT.md
```

**Review past sessions:**
```bash
cat ~/.claude/over-50s-health-advisor/context/SESSION_NOTES.md
```

**Update preferences:**
```bash
code ~/.claude/over-50s-health-advisor/context/CLIENT_PREFERENCES.md
```

## Installation Preservation

When you reinstall or upgrade the agent with `./install.sh`, your existing context files are **preserved**. The installation script:
- Only copies template files if they don't already exist
- Never overwrites your personal context files
- Reports which files were preserved during installation

## Project Scope vs User Scope

**User scope** (recommended):
- Agent installed to `~/.claude/agents/`
- Context files in `~/.claude/over-50s-health-advisor/context/`
- Agent works from any directory
- Personal health data stored in home directory

**Project scope** (for development):
- Agent installed to `.claude/agents/` in repository
- Context files in `context/user/` (manually copied from templates)
- Agent only works within project directory
- Useful for testing and development
