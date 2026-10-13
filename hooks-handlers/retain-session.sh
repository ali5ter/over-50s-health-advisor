#!/usr/bin/env bash
# retain-session.sh — Retain the current session's per-session history file into the
# Hindsight `health` bank via scripts/hindsight-retain.py (the MCP transport the server
# exposes). A Stop hook in hooks/hooks.json.
#
# The old implementation POSTed REST /v1/{bank}/documents, which 404s: the server speaks
# MCP at /mcp/{bank}/ and has no REST "create document" route. This now delegates the
# transport to hindsight-retain.py, which also keeps the idempotency manifest, so a
# session already caught up by a backfill is not re-retained.
#
# Fails silently (exit 0) when:
#   - agent_type does not match (non-advisor session)
#   - HINDSIGHT_RETAIN_ENABLED is not "true"
#   - the session file does not exist yet
#   - the server is unreachable or the retain fails (logged to stderr, non-blocking)
# The file on disk is the record; nothing is lost if this does not run.

set -euo pipefail

# --- Agent scoping (same pattern as stop-session-log.sh) ---
_agent_type=""
if [ -n "${ARGUMENTS:-}" ]; then
  _agent_type=$(echo "$ARGUMENTS" | jq -r '.agent_type // empty' 2>/dev/null || true)
fi
if [ -n "${agent_type:-}" ]; then
  _agent_type="$agent_type"
fi
if [ "$_agent_type" != "over-50s-health:advisor" ]; then
  exit 0
fi

# --- Configuration ---
# The enable gate (and any host/URL overrides) come from a small config file the
# hook sources itself, set the same way the api key is: a persistent file under
# ~/.hindsight/, not an interactive-shell profile. This keeps the gate
# independent of how Claude Code was launched (login shell, editor, CI) and
# mirrors how hindsight-retain.py already reads HINDSIGHT_API_KEY from
# ~/.hindsight/api_key rather than from process env. The path is overridable via
# HINDSIGHT_CONFIG for testing or alternate locations.
: "${HINDSIGHT_CONFIG:=$HOME/.hindsight/retain.env}"
if [ -f "$HINDSIGHT_CONFIG" ]; then
  # shellcheck disable=SC1090
  source "$HINDSIGHT_CONFIG"
fi

: "${HINDSIGHT_RETAIN_ENABLED:=false}"
if [ "$HINDSIGHT_RETAIN_ENABLED" != "true" ]; then
  exit 0
fi

# --- Locate the helper (works under the plugin and standalone) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
RETAIN="$REPO_ROOT/scripts/hindsight-retain.py"

# --- Determine the session file to retain ---
: "${CONTEXT_DIR:=$HOME/.claude/over-50s-health-advisor/context}"
: "${TODAY_DATE:=$(date +%Y-%m-%d)}"
: "${YEAR:=$(date +%Y)}"

SESSION_FILE="${CONTEXT_DIR}/history/${YEAR}/${YEAR}-${TODAY_DATE}.md"

if [ ! -f "$SESSION_FILE" ]; then
  # No session file yet — nothing to retain.
  exit 0
fi

doc_date=$(jq -r '.date // empty' "$SESSION_FILE" 2>/dev/null || echo "$TODAY_DATE")

# Retain the single session document. The helper skips it if it is already in the
# manifest (e.g. caught up by a backfill) and exits non-zero only on a real failure.
if ! python3 "$RETAIN" --id "$SESSION_FILE" --content "$(cat "$SESSION_FILE")" \
      --date "$doc_date" --tag session 2>/dev/null; then
  echo "retain-session: retain failed for $SESSION_FILE; the file on disk is the record" >&2
fi

exit 0
