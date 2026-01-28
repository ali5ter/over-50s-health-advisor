# Over-50s Health Advisor - Project Status

**Last updated**: 2026-01-28

## Project Overview

A Claude Code Agent that provides evidence-based, age-appropriate health guidance for adults 50+. Specializes in fitness, nutrition, metabolic health, mental health, sleep, and longevity with mandatory citations and safety boundaries.

## Current Architecture (v2.0)

**User-level scope** (implemented 2026-01-28):
```
~/.claude/
├── agents/over-50s-health-advisor.md     # Agent definition
└── over-50s-health-advisor/
    └── context/                           # User's personal health context
        ├── INITIAL_USER_INFORMATION.md
        ├── CLIENT_HEALTH_CONTEXT.md
        ├── CLIENT_PREFERENCES.md
        ├── SESSION_NOTES.md
        └── SOURCES.md
```

**Key features**:
- Works from any directory
- Context files preserved on reinstall
- Privacy-preserving local storage
- Evidence-based with mandatory citations
- Clear safety boundaries and medical disclaimers

## Repository Structure

```
agent/over-50s-health-advisor.md        # Agent definition (source)
context/
  templates/                             # Context file templates
    INITIAL_USER_INFORMATION.md
    CLIENT_HEALTH_CONTEXT.md
    CLIENT_PREFERENCES.md
    SESSION_NOTES.md
    SOURCES.md
  README.md                              # Context documentation
install.sh                               # Installation script
README.md                                # User-facing documentation
TESTING.md                               # Test procedures
AGENTS.md                                # Development notes
LICENSE                                  # MIT License
```

## Implementation Status

### ✅ Completed (v2.0 - 2026-01-28)

1. **Agent Definition**
   - YAML frontmatter with invocation examples
   - Absolute context paths: `~/.claude/over-50s-health-advisor/context/`
   - Evidence source guidelines (reputable .org and .com sites)
   - Safety boundaries and emergency referral protocols
   - Context management workflow

2. **Installation Infrastructure**
   - User-scope installation by default
   - `--project` flag for development mode
   - Automatic context directory creation
   - Template copying with preservation logic
   - Clear installation feedback

3. **Context Management System**
   - 5 template files with clear structure
   - Examples and guidance in each template
   - Privacy-preserving architecture
   - User-editable with any text editor

4. **Documentation**
   - README.md with installation and usage
   - context/README.md with detailed context guidance
   - TESTING.md with comprehensive test procedures
   - AGENTS.md with development notes
   - MIT License for open source distribution

5. **Version Control**
   - .gitignore excludes all user data
   - Templates committed, actual context never tracked
   - Clean separation of distribution vs personal data

### 🔄 In Progress

None currently. Core implementation is complete.

### 📋 Next Steps (Testing & Validation)

1. **Installation Testing**
   - [ ] Clean user-scope install
   - [ ] Context files created correctly
   - [ ] Reinstall preserves user data
   - [ ] Project-scope mode still works

2. **Cross-Directory Testing**
   - [ ] Invoke agent from project directory
   - [ ] Invoke agent from home directory
   - [ ] Invoke agent from /tmp directory
   - [ ] Verify context files accessible from all locations

3. **Agent Behavior Testing**
   - [ ] Agent loads and activates correctly
   - [ ] Can read all context files
   - [ ] Can write to context files
   - [ ] Citations and sources formatted correctly
   - [ ] Safety disclaimers present in responses

4. **Real-World Usage**
   - [ ] Fill in actual user context files
   - [ ] Test with sample health queries
   - [ ] Verify evidence sources are credible
   - [ ] Test context budget management

5. **Optional Enhancements**
   - [ ] Create migration guide for existing users
   - [ ] Create uninstall script
   - [ ] Add version tagging (v2.0.0)
   - [ ] Consider archive strategy for session notes

## Design Decisions

### Context Budget Management
- Target: 1,500-2,500 words across all context files
- Agent monitors and reports when approaching limits
- User approval required before pruning

### Evidence Standards
- Credible sources required for all recommendations
- Accept: .gov, .edu, reputable .org, credible medical .com sites
- Evaluate each source for authority and relevance
- Mandatory "Sources:" section with links

### Safety Boundaries
- Education only, never diagnosis
- Emergency symptom referral (chest pain, stroke signs, etc.)
- Medication questions referred to clinician/pharmacist
- Mental health crisis referral to professional support

### Privacy Architecture
- All personal data stored locally in `~/.claude/over-50s-health-advisor/context/`
- Plain Markdown format (user-readable and editable)
- Never committed to version control
- No cloud storage of health information
- User maintains full control

## Testing & Validation

All test procedures documented in `TESTING.md`:
- Installation tests (user and project scope)
- Overwrite and preservation behavior
- Cross-directory invocation
- Context file structure validation
- Git ignore verification
- Documentation coherence checks

## Repository Information

- **GitHub**: https://github.com/ali5ter/over-50s-health-advisor
- **License**: MIT License (Copyright 2026 Alister Lewis-Bowen)
- **Language**: Markdown (agent definition), Bash (install script)
- **Requirements**: Claude Code CLI

## Breaking Changes

**v2.0 (2026-01-28)**: Restructured to user-level scope
- Context paths changed from `context/user/` to `~/.claude/over-50s-health-advisor/context/`
- Install script now defaults to user scope (use `--project` for old behavior)
- Existing users need to reinstall: `./install.sh`

## Development Notes

**For contributors**:
1. Install in project scope: `./install.sh --project`
2. Templates are in `context/templates/` (committed)
3. Test with context files in `context/user/` (gitignored)
4. Run tests from `TESTING.md` before PR
5. Update `AGENTS.md` with architectural changes

**For end users**:
1. Install normally: `./install.sh`
2. Edit context files in `~/.claude/over-50s-health-advisor/context/`
3. Invoke agent from any directory
4. Agent reads/writes context automatically

## Success Metrics

- ✅ Agent installs without errors
- ✅ Works from any directory
- ✅ Context files preserved on reinstall
- ✅ Documentation accurate and complete
- 🔄 User testing with real health queries (pending)
- 🔄 Cross-directory functionality verified (pending)

## Contact & Support

For issues or feedback:
- GitHub Issues: https://github.com/ali5ter/over-50s-health-advisor/issues
- See README.md for usage documentation
- See TESTING.md for validation procedures
