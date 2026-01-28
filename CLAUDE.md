# Implementation Plan: Over-50s Health Advisor

## Analysis

After reviewing the PROJECT_REQUIREMENTS_DOCUMENT.md, this is a well-defined project for creating a specialized health advisor for adults 50+. The requirements are clear about:

- Domain specialization (fitness, nutrition, metabolic health, longevity)
- Age-appropriate guidance with safety boundaries
- Evidence-based approach with mandatory citations
- Local context management (privacy-preserving)
- Integration with Claude Code as an agent

## Recommended Implementation: Agent-Based Architecture

**Primary implementation: Custom Claude Code Agent**

This should be implemented as a **single specialized agent** rather than a skill or workflow because:

1. **State Management**: Requires maintaining evolving user context across sessions
2. **Complex Workflows**: Multi-step processes (gather context → research → advise → update context)
3. **Specialized Tools**: Needs WebSearch, WebFetch, Read, Write for evidence gathering
4. **Domain Expertise**: Requires deep specialization in 50+ health guidance
5. **Invocable Pattern**: Should be callable when health/fitness topics arise

**Not a skill** because:
- Too complex for single-command execution
- Requires multi-turn conversations and context building
- Not a simple transformation or command

**Not a workflow** because:
- Requires autonomous decision-making and research
- Needs to adapt responses based on user context
- More interactive than procedural

## Architecture Overview

```
┌─────────────────────────────────────┐
│  over-50s-health-advisor.md         │  ← Agent definition (YAML + instructions)
│  (in .claude/agents/)                │
└─────────────────────────────────────┘
                 │
                 ├─ Tools: Read, Write, WebSearch, WebFetch
                 │
                 ├─ Reads from: context/templates/*.md (reference)
                 │
                 └─ Maintains: context/user/*.md (gitignored)
                              ├─ INITIAL_USER_INFORMATION.md
                              ├─ CLIENT_HEALTH_CONTEXT.md
                              ├─ CLIENT_PREFERENCES.md
                              ├─ SESSION_NOTES.md
                              └─ SOURCES.md
```

## Implementation Components

### 1. Agent Definition File
**File**: `agent/over-50s-health-advisor.md`

Structure:
- YAML frontmatter (name, description with examples, model, color, tools)
- Markdown body with:
  - Role and purpose
  - Context file locations
  - Safety boundaries and medical disclaimers
  - Evidence and citation policy
  - Workflow steps
  - Output format guidelines
  - Success indicators

### 2. Context Management System
**Templates** (committed): `context/templates/*.md`
- Serve as examples and structure reference
- Read-only for the agent

**User Data** (gitignored): `context/user/*.md`
- Agent reads/writes here exclusively
- Contains actual user health information
- Never committed to version control

### 3. Installation Infrastructure
**File**: `install.sh`

Features:
- Copy agent definition to `.claude/agents/` (project scope by default)
- Optional `--user` flag for `~/.claude/agents/` (user scope)
- Create `context/user/` directory structure
- Copy templates to `context/user/` if they don't exist
- Confirmation prompts or `--force` flag for overwrites

### 4. Documentation
- `README.md`: Usage guide, installation instructions, safety disclaimer
- `LICENSE`: Open source license for public distribution
- `context/README.md`: Explanation of context file structure

## Key Design Decisions

### Context Budget Management
- Target: 1,500-2,500 words across all context files
- Agent monitors and reports when approaching limits
- Archival strategy for older session notes
- Always request user approval before pruning

### Evidence & Safety Policy
- Every response with recommendations includes citations
- Mandatory "Sources:" section with markdown links
- Safety disclaimers in every advisory response
- Clear boundaries: education not diagnosis

### Privacy Architecture
- All personal health data in `context/user/` (gitignored)
- No cloud storage of user data
- Templates provide structure without exposing data
- User maintains full control to edit/delete

## Open Questions for Clarification

### 1. Scope & Features
- Should the agent proactively offer to create workout plans, or only when asked?
- How detailed should meal plans be (specific recipes vs general guidelines)?
- Should the agent track progress metrics over time, or just reference them?

### 2. Context Management
- Should the agent automatically update context files during conversations, or always ask first?
- What's the preferred archival strategy (single archive file vs yearly files)?
- Should context files use structured format (YAML frontmatter + markdown) or pure markdown?

### 3. Installation & Distribution
- Should install script be idempotent (safe to run multiple times)?
- Do you want versioning for the agent definition?
- Should there be an uninstall script?

### 4. Evidence Standards
- Acceptable source types: Only .gov/.edu, or include reputable .org and .com health sites?
- How recent should evidence be (prefer sources from last X years)?
- Should the agent maintain a curated sources database in SOURCES.md?

### 5. User Interaction
- Should the agent ask for initial profile information on first invocation?
- Preferred tone: clinical professional, friendly coach, or balanced blend?
- Should responses include visuals/tables for plans, or text-only?

## Implementation Risk Assessment

**Low Risk**:
- Agent definition creation
- Template file structure
- Basic install script

**Medium Risk**:
- Context pruning logic (needs careful testing)
- Citation format consistency
- Safety boundary edge cases

**High Risk**:
- None identified (safety disclaimers mitigate medical advice liability)

## Success Criteria

1. Agent successfully installs via `install.sh`
2. Agent triggers correctly when user asks about 50+ health topics
3. All advice includes evidence-based citations with links
4. Context files maintain user data locally (verified gitignored)
5. Safety disclaimers present in every advisory response
6. User can easily edit/delete context files
7. Agent reports when context budget approached
8. README clearly explains usage and safety boundaries

## Next Steps

1. **Clarify open questions** (listed above)
2. **Create agent definition** following the template in PRD
3. **Build context template files** with clear structure
4. **Write install script** with proper error handling
5. **Create documentation** (README, LICENSE)
6. **Test installation** in clean environment
7. **Validate agent behavior** with sample health queries
8. **Review safety boundaries** with edge case testing
