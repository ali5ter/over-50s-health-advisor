# TESTING

This document describes the manual verification procedures for the Over-50s Health Advisor agent.

## Installation Tests

### User scope installation (default)

```bash
./install.sh
```

**Expected results:**
- Creates `~/.claude/agents/over-50s-health-advisor.md`
- Creates `~/.claude/over-50s-health-advisor/context/` directory
- Copies all 5 template files to context directory
- Reports installation location and context directory
- Displays success message indicating agent works from any directory

**Verification:**
```bash
ls -la ~/.claude/agents/over-50s-health-advisor.md
ls -la ~/.claude/over-50s-health-advisor/context/
```

### Project scope installation

```bash
./install.sh --project
```

**Expected results:**
- Creates `.claude/agents/over-50s-health-advisor.md` in repository
- Does NOT create or copy context files
- Reports project scope installation
- Advises to manually copy templates

**Verification:**
```bash
ls -la .claude/agents/over-50s-health-advisor.md
```

### Overwrite behavior

**Test 1: Overwrite prompt**
```bash
./install.sh
# Run again without --force
./install.sh
```

**Expected:** Prompts for overwrite confirmation

**Test 2: Force overwrite**
```bash
./install.sh --force
```

**Expected:** Overwrites without prompting

### Context preservation on reinstall

**Setup:**
```bash
# Install first time
./install.sh

# Add test content
echo "Test data" >> ~/.claude/over-50s-health-advisor/context/INITIAL_USER_INFORMATION.md
```

**Test:**
```bash
./install.sh --force
```

**Expected:**
- Agent file is overwritten
- Context files are preserved (not overwritten)
- Installation reports "Preserved 5 existing file(s)"

**Verification:**
```bash
grep "Test data" ~/.claude/over-50s-health-advisor/context/INITIAL_USER_INFORMATION.md
```

Should find the test data still present.

## Cross-Directory Invocation Test

**Purpose:** Verify the agent works from any directory when installed to user scope.

**Setup:**
```bash
./install.sh
```

**Test:**
```bash
cd ~
# Start Claude Code from home directory
# Invoke the over-50s-health-advisor agent
# Ask: "What context files do you have access to?"
```

**Expected:**
- Agent activates successfully
- Agent reports context file paths: `~/.claude/over-50s-health-advisor/context/*.md`
- Agent can read and write to context files

**Test from another directory:**
```bash
cd /tmp
# Start Claude Code
# Invoke the agent again
```

**Expected:** Same behavior - agent works from /tmp directory

## Agent Definition Verification

**Check context paths:**
```bash
grep "Context inputs" -A 5 agent/over-50s-health-advisor.md
```

**Expected:** All paths should be absolute paths starting with `~/.claude/over-50s-health-advisor/context/`

**Check evidence guidelines:**
```bash
grep -A 3 "Evidence, citations, and safety" agent/over-50s-health-advisor.md
```

**Expected:** Should include guidelines about accepting reputable .org and .com domains

## Context File Structure

**Check template files exist:**
```bash
ls -la context/templates/
```

**Expected:**
- `INITIAL_USER_INFORMATION.md`
- `CLIENT_HEALTH_CONTEXT.md`
- `CLIENT_PREFERENCES.md`
- `SESSION_NOTES.md`
- `SOURCES.md`

**Verify each template has structure:**
```bash
head -n 20 context/templates/INITIAL_USER_INFORMATION.md
```

**Expected:** Templates should have headers, example content, and "Last updated" fields

## Git Ignore Verification

**Check that user context is ignored:**
```bash
git status
```

**Expected:**
- `.claude/` directory not shown (if it exists)
- `context/user/` not shown (if it exists)
- Only tracked files appear in status

## Documentation Coherence

**README structure matches reality:**
```bash
diff <(ls -1) <(grep -E '^\w+\/' README.md | sort)
```

**Expected:** Repository structure in README matches actual directory structure

**Installation instructions are accurate:**
- README should show user scope as default
- README should mention `--project` flag for development
- README should reference `~/.claude/over-50s-health-advisor/context/` paths

**Context README is accurate:**
```bash
grep "~/.claude/over-50s-health-advisor/context" context/README.md
```

**Expected:** Multiple references to the user-level context path

## Clean Uninstall Test

**Remove all installed files:**
```bash
rm -rf ~/.claude/agents/over-50s-health-advisor.md
rm -rf ~/.claude/over-50s-health-advisor/
```

**Verify removal:**
```bash
ls ~/.claude/agents/over-50s-health-advisor.md 2>&1
ls ~/.claude/over-50s-health-advisor/ 2>&1
```

**Expected:** Both commands should report "No such file or directory"

**Reinstall:**
```bash
./install.sh
```

**Expected:** Fresh installation with all context templates copied

## Edge Cases

### Missing templates directory

**Test:**
```bash
mv context/templates context/templates.bak
./install.sh
```

**Expected:** Installation should complete but warn about missing template files

**Cleanup:**
```bash
mv context/templates.bak context/templates
```

### Partial context directory

**Setup:**
```bash
./install.sh
rm ~/.claude/over-50s-health-advisor/context/SOURCES.md
```

**Test:**
```bash
./install.sh --force
```

**Expected:**
- Preserves existing 4 files
- Copies missing SOURCES.md template
- Reports "Copied 1 template(s)" and "Preserved 4 existing file(s)"

### Help text

**Test:**
```bash
./install.sh --help
```

**Expected:** Displays clear usage information with examples

**Test invalid option:**
```bash
./install.sh --invalid
```

**Expected:** Shows error message and help text, exits with non-zero status

## Integration Test Checklist

- [ ] Clean install (user scope)
- [ ] Context files created with templates
- [ ] Agent invoked from project directory
- [ ] Agent invoked from home directory
- [ ] Agent invoked from /tmp directory
- [ ] Agent can read context files
- [ ] Agent can write to context files
- [ ] Reinstall preserves context data
- [ ] Project scope installation works
- [ ] Force flag bypasses prompts
- [ ] Documentation matches implementation
- [ ] Git ignores user data correctly

## Success Criteria

All tests should pass with these outcomes:
1. Agent installs to user scope by default
2. Context files are created in `~/.claude/over-50s-health-advisor/context/`
3. Agent works from any directory
4. Reinstallation preserves existing context files
5. Project scope mode still available for development
6. Documentation accurately reflects new architecture
7. No user data tracked by Git
