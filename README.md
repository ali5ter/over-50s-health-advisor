# Over-50s Health Advisor

A Claude Code Agent definition for evidence-based, age-appropriate health, fitness, nutrition, and longevity guidance for adults 50+. The agent is designed to work with local context files only and always recommends confirming advice with a healthcare professional.

## Features

- Evidence-based guidance with citations and a Sources section
- Safety boundaries and red-flag referral policy
- Local context management via Markdown files
- Install via Claude Code plugin system (`/plugin install over-50s-health-advisor@ali5ter`)
- Automatic context file creation on first run

## Repository structure

This repository contains the agent definition and context templates for distribution. When installed via the plugin system, the agent is managed by Claude Code and your personal context files are stored in your home directory.

```text
agents/
  over-50s-health-advisor.md      # Agent definition (source)
context/
  templates/                       # Reference context templates
    INITIAL_USER_INFORMATION.md
    CLIENT_HEALTH_CONTEXT.md
    CLIENT_PREFERENCES.md
    SESSION_NOTES.md
    SOURCES.md
  README.md
.claude-plugin/
  plugin.json                      # Plugin manifest
  marketplace.json                 # Marketplace registration
migrate                            # Migration script for v2.x users
README.md
LICENSE
```

After installation, your personal context files are stored at:

```text
~/.claude/over-50s-health-advisor/
    context/                       # Your personal context files (auto-created on first run)
        ├── INITIAL_USER_INFORMATION.md
        ├── CLIENT_HEALTH_CONTEXT.md
        ├── CLIENT_PREFERENCES.md
        ├── SESSION_NOTES.md
        └── SOURCES.md
```

## Install

Inside Claude Code, run:

```
/plugin marketplace add ali5ter/claude-plugins
/plugin install over-50s-health-advisor@ali5ter
```

The first time you start a health conversation, the agent automatically creates your context files at `~/.claude/over-50s-health-advisor/context/`.

## Migrating from v2.x

If you previously installed via `./install.sh`, run the migration script from this repo:

```bash
./migrate
```

This removes the old manually-installed agent file. Your context files are preserved. Then install via the plugin commands above.

## Usage

After installation, context files are automatically created at `~/.claude/over-50s-health-advisor/context/` on your first conversation.

1. Fill in `~/.claude/over-50s-health-advisor/context/INITIAL_USER_INFORMATION.md` and `CLIENT_PREFERENCES.md` with your information.
2. Keep `CLIENT_HEALTH_CONTEXT.md` and `SESSION_NOTES.md` current as new information is shared with the agent.
3. Maintain `SOURCES.md` as a curated reference list (the agent will add sources; you can remove low-quality ones and add high-quality evidence).
4. Use the agent from any directory in Claude Code. The agent will read and update these context files automatically.
5. Keep the "Last updated" dates accurate in each file.

## Starting a Conversation

Once you've filled in your initial context files, you can begin interacting with the agent. Here are some ways to start:

**Initial Engagement:**
- "Where do you see the context files?" - The agent will analyze your context and provide a summary of your health profile, helping establish rapport.
- "Can you review my health information and suggest areas to focus on?"
- "What do you know about me so far?"

**Direct Queries:**
- "What strength training program would you recommend for me?"
- "Can you suggest a weekly meal plan that supports my goals?"
- "How can I improve my metabolic health based on my recent labs?"
- "What mobility exercises should I prioritize?"

**Specific Requests:**
- "Review my recent blood panel and explain what the trends mean"
- "Create a 4-week progressive workout plan for me"
- "Suggest supplements appropriate for my age and health status"

The agent will read your context files, provide evidence-based guidance with citations, and update your context files as you share new information.

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
