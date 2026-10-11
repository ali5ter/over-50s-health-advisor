#!/usr/bin/env bash
#
# sync-templates.sh
#
# @description  Copies context file templates from the plugin cache to a stable
#               user-owned path so the advisor agent can read them without
#               needing to know the version-specific plugin cache location.
#               Runs on every SessionStart; safe to run repeatedly.
#
# @param        CLAUDE_PLUGIN_ROOT  Set by Claude Code at hook execution time.
# @side_effects Writes to ~/.claude/over-50s-health-advisor/templates/
#               (creates directory if absent; overwrites stale templates).
# @exit         0 always — hook failures should not block session start.

src="${CLAUDE_PLUGIN_ROOT}/context/templates"
dest="${HOME}/.claude/over-50s-health-advisor/templates"

mkdir -p "${dest}"

if [[ -d "${src}" ]]; then
    # Only copy files that don't already exist — never overwrite user data
    for f in "${src}"/*.md; do
        [[ -f "$f" ]] || continue
        [[ -f "${dest}/$(basename "$f")" ]] && continue
        cp "$f" "${dest}/" 2>/dev/null || true
    done
    for f in "${src}"/*.csv; do
        [[ -f "$f" ]] || continue
        [[ -f "${dest}/$(basename "$f")" ]] && continue
        cp "$f" "${dest}/" 2>/dev/null || true
    done
    # Sync history/ subdirectory templates
    if [[ -d "${src}/history" ]]; then
        mkdir -p "${dest}/history"
        for f in "${src}/history"/*.md; do
            [[ -f "$f" ]] || continue
            [[ -f "${dest}/history/$(basename "$f")" ]] && continue
            cp "$f" "${dest}/history/" 2>/dev/null || true
        done
    fi
fi

exit 0
