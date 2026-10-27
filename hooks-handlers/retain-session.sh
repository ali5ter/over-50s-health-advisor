#!/usr/bin/env bash
# retain-session.sh — Retain the current session's per-session history file into the Hindsight
# `health` bank via scripts/hindsight-retain.py (the MCP transport the server exposes). Registered
# on both SubagentStop and Stop in hooks/hooks.json.
#
# Why SubagentStop: the advisor runs as a *subagent* (`over-50s-health:advisor`), and a subagent's
# end fires SubagentStop, not Stop — registering on Stop only (the prior wiring) meant the hook
# never fired for the agent it served. It is also kept on Stop so an explicit
# `claude --agent over-50s-health:advisor` main session is covered. The retain is idempotent (the
# manifest dedupes by document id), so firing on both events is harmless.
#
# Two more prior bugs, both fixed here:
#   - agent_type was read from $ARGUMENTS, which a `command` hook never receives, so the scope
#     check fell through to exit 0 on every session. Scoping now mirrors guard-bash-scope.sh and
#     reads agent_type from the hook's own stdin JSON.
#   - the session path was built as history/${YEAR}/${YEAR}-${TODAY_DATE}.md, doubling the year
#     into a file no backfill ever writes, so even a firing hook found nothing to retain.
#
# The old REST POST /v1/{bank}/documents route 404s (the server has no REST create-doc route); this
# delegates the transport to hindsight-retain.py, which also keeps the idempotency manifest, so a
# session already caught up by a backfill is not re-retained.
#
# Fails silently (exit 0) when:
#   - agent_type does not match (non-advisor session)
#   - HINDSIGHT_RETAIN_ENABLED is not "true"
#   - the session file does not exist yet
#   - the server is unreachable or the retain fails (logged to stderr, non-blocking)
# The file on disk is the record; nothing is lost if this does not run.

set -euo pipefail

readonly ADVISOR_AGENT_TYPE="over-50s-health:advisor"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"

# hooks/hooks.json applies plugin-wide with no per-agent matcher, so every session invokes this
# script on end. Read agent_type from the hook's own stdin JSON (same as guard-bash-scope.sh) and
# no-op for anything that isn't the advisor.
agent_type="$(jq -r '.agent_type // empty' <<<"$input" 2>/dev/null || true)"
[[ "$agent_type" == "$ADVISOR_AGENT_TYPE" ]] || exit 0

# --- Configuration (the enable gate comes from ~/.hindsight/retain.env, sourced the same way the
# api key is: a persistent file, not an interactive-shell profile, so it works regardless of how
# Claude Code was launched. Overridable via HINDSIGHT_CONFIG for testing.) ---
: "${HINDSIGHT_CONFIG:=$HOME/.hindsight/retain.env}"
if [ -f "$HINDSIGHT_CONFIG" ]; then
  # shellcheck disable=SC1090
  source "$HINDSIGHT_CONFIG"
fi

: "${HINDSIGHT_RETAIN_ENABLED:=false}"
if [ "$HINDSIGHT_RETAIN_ENABLED" != "true" ]; then
  exit 0
fi

# A sourced variable is NOT exported to the child `python3` by default, so hindsight-retain.py would
# fall back to its own defaults and silently ignore any endpoint/bank/manifest/key override in the
# sourced file. Export the Hindsight family so the documented "overridable via HINDSIGHT_CONFIG"
# behaviour actually reaches the helper (export of an unset name is a harmless no-op).
export HINDSIGHT_API_KEY HINDSIGHT_MCP_URL HINDSIGHT_BASE HINDSIGHT_BANK HINDSIGHT_MANIFEST 2>/dev/null || true

# --- Locate the helper (works under the plugin and standalone) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
RETAIN="$REPO_ROOT/scripts/hindsight-retain.py"

# --- Determine the session file to retain ---
: "${CONTEXT_DIR:=$HOME/.claude/over-50s-health-advisor/context}"
: "${TODAY_DATE:=$(date +%Y-%m-%d)}"
: "${YEAR:=${TODAY_DATE:0:4}}"

# history/${YEAR}/${TODAY_DATE}.md — TODAY_DATE is already YYYY-MM-DD, so the year must NOT be
# repeated on the filename (the old code produced history/2026/2026-2026-10-26.md, which no
# backfill ever writes and so could never match a retained document).
SESSION_FILE="${CONTEXT_DIR}/history/${YEAR}/${TODAY_DATE}.md"

if [ ! -f "$SESSION_FILE" ]; then
  # No session file yet — nothing to retain.
  exit 0
fi

# The per-session file carries a YAML `date` in its frontmatter; fall back to today if absent or
# unparseable. jq exits 0 on a missing key, so guard the empty output explicitly.
doc_date="$(jq -r '.date // empty' "$SESSION_FILE" 2>/dev/null || true)"
[ -n "$doc_date" ] || doc_date="$TODAY_DATE"

# Retain the single session document. The helper skips it if it is already in the manifest (e.g.
# caught up by a backfill) and exits non-zero only on a real failure.
if ! python3 "$RETAIN" --id "$SESSION_FILE" --content "$(cat "$SESSION_FILE")" \
      --date "$doc_date" --tag session 2>/dev/null; then
  echo "retain-session: retain failed for $SESSION_FILE; the file on disk is the record" >&2
fi

exit 0
