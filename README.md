# Over-50s Health Advisor

A Claude Code Agent definition for evidence-based, age-appropriate health, fitness, nutrition, and longevity guidance for adults 50+. The agent is designed to work with local context files only and always recommends confirming advice with a healthcare professional.

## Features

- Evidence-based guidance with citations and a Sources section
- Safety boundaries and red-flag referral policy
- Local context management via Markdown files
- Install script for project or User scope

## Repository structure

```text
agent/
  over-50s-health-advisor.md
context/
  templates/
    INITIAL_USER_INFORMATION.md
    CLIENT_HEALTH_CONTEXT.md
    CLIENT_PREFERENCES.md
    SESSION_NOTES.md
    SOURCES.md
  user/   # gitignored
  README.md
install.sh
PROJECT_REQUIREMENTS_DOCUMENT.md
README.md
LICENSE
```

## Install

Project scope (default):

```bash
./install.sh
```

User scope:

```bash
./install.sh --User
```

Overwrite without prompting:

```bash
./install.sh --force
```

## Usage

1. Copy templates into `context/User/`:

   ```bash
   cp -R context/templates/* context/User/
   ```

2. Fill in `context/User/INITIAL_USER_INFORMATION.md` and `context/User/CLIENT_PREFERENCES.md`.
3. Keep `context/User/CLIENT_HEALTH_CONTEXT.md` and `context/User/SESSION_NOTES.md` current.
3. Use the agent in Claude Code, and update context files after new information is shared.

## Safety and medical boundaries

- Educational guidance only, not diagnosis.
- Immediate referral for emergency symptoms.
- Always include a reminder to confirm with a healthcare professional.

## Evidence and citations

- Use credible, evidence-based sources.
- Provide citations with links in every response that includes recommendations.
- End responses with a **Sources** section.

## License

MIT License, Copyright (c) 2026 Alister Lewis-Bowen.
