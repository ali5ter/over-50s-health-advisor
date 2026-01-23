# Context Files

This repository ships **templates** only. Real User data must live in `context/user/` and is ignored by Git.

## Templates

Templates are in `context/templates/`. Copy them into `context/user/` before use:

```bash
cp -R context/templates/* context/user/
```

## Required vs optional context

Required (minimum for personalized guidance):
- INITIAL_USER_INFORMATION.md
- CLIENT_PREFERENCES.md

Optional but strongly recommended:
- CLIENT_HEALTH_CONTEXT.md
- SESSION_NOTES.md
- SOURCES.md

## Artifact ingestion

The User can provide artifacts (CSV, PDFs) for the Agent to summarize and extract key data. The Agent should:
- Ask for consent to extract and store summaries.
- Store only relevant, minimal data.
- Reference the artifact and extraction date in `SESSION_NOTES.md` or `CLIENT_HEALTH_CONTEXT.md`.
- Keep the original artifact in a User-managed location (not committed).
