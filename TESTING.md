# TESTING

This document describes the manual checks for the Over-50s Health Advisor repository.

## Install script

Project scope (default):

```bash
./install.sh
```

Expected:
- Creates `.claude/agents/over-50s-health-advisor.md` in the repo.

User scope:

```bash
./install.sh --User
```

Expected:
- Creates `~/.claude/agents/over-50s-health-advisor.md`.

Overwrite behavior:

1. Run `./install.sh` twice and confirm the overwrite prompt appears.
2. Run `./install.sh --force` and confirm it overwrites without prompting.

## Context templates

Copy templates into the User data folder:

```bash
cp -R context/templates/* context/user/
```

Expected:
- All context files exist in `context/user/`.

## Git ignore

Expected:
- `context/user/` remains untracked by Git (no entries in `git status`).

## Agent definition sanity

Expected:
- All context paths in `agent/over-50s-health-advisor.md` reference `context/user/`.
- All references to the User are capitalized as "User" in documentation and agent definitions.

## Documentation coherence

Expected:
- README repo structure matches actual layout.
- PRD context structure matches README and agent definition.
