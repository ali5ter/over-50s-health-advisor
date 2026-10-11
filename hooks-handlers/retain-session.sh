#!/usr/bin/env bash
# retain-session.sh — POST the current session's per-session history file to Hindsight for
# long-term memory retention. A Stop hook in hooks/hooks.json.
#
# Fails silently (exit 0) when:
#   - agent_type does not match (non-advisor session)
#   - HINDSIGHT_RETAIN_ENABLED is not "true"
#   - Hindsight server is unreachable
# The file on disk is already the record; nothing is lost if this does not run.

set -euo pipefail

# --- Agent scoping (same pattern as stop-session-log.sh) ---
_agent_type=""
if [ -n "${ARGUMENTS:-}" ]; then
  _agent_type=$(echo "$ARGUMENTS" | jq -r '.agent_type // empty' 2>/dev/null || true)
fi
if [ -z "${agent_type:-}" ]; then
  # agent_type may be passed directly by Claude Code in some hook types
  :
elif [ -n "$agent_type" ]; then
  _agent_type="$agent_type"
fi
if [ "$_agent_type" != "over-50s-health:advisor" ]; then
  exit 0
fi

# --- Configuration ---
: "${HINDSIGHT_RETAIN_ENABLED:=false}"
if [ "$HINDSIGHT_RETAIN_ENABLED" != "true" ]; then
  exit 0
fi

: "${HINDSIGHT_URL:=http://192.168.1.63:8888}"
: "${HINDSIGHT_API_KEY:=}"
: "${HINDSIGHT_BANK:=health}"

if [ -z "$HINDSIGHT_API_KEY" ]; then
  # Try to read from the Hindsight config directory if it exists
  if [ -f ~/.hindsight/api_key ]; then
    HINDSIGHT_API_KEY=$(cat ~/.hindsight/api_key)
  fi
fi

if [ -z "$HINDSIGHT_API_KEY" ]; then
  exit 0
fi

# --- Determine the session file to retain ---
: "${CONTEXT_DIR:=$HOME/.claude/over-50s-health-advisor/context}"
: "${TODAY_DATE:=$(date +%Y-%m-%d)}"
: "${YEAR:=$(date +%Y)}"

SESSION_FILE="${CONTEXT_DIR}/history/${YEAR}/${YEAR}-${TODAY_DATE}.md"

if [ ! -f "$SESSION_FILE" ]; then
  # No session file yet — nothing to retain
  exit 0
fi

# --- POST to Hindsight ---
# Hindsight's /v1/{bank}/documents endpoint accepts:
#   POST /v1/{bank}/documents
#   Body: [{ "id": "...", "content": "...", "metadata": { "date": "..." } }]
# We send the session file as a single document.

_PAYLOAD=$(jq -n --arg id "$SESSION_FILE" \
                  --arg content "$(cat "$SESSION_FILE")" \
                  --arg date "$(jq -r '.date // empty' "$SESSION_FILE" 2>/dev/null || echo "$TODAY_DATE")" \
                  '{id: $id, content: $content, metadata: {date: $date}}')

HTTP_CODE=$(curl -s -w "%{http_code}" \
  -X POST "${HINDSIGHT_URL}/v1/${HINDSIGHT_BANK}/documents" \
  -H "Authorization: Bearer ${HINDSIGHT_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$_PAYLOAD" 2>/dev/null || echo "000")

# 200 or 201 means success; 409 means the document already exists (idempotent)
if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ] && [ "$HTTP_CODE" != "409" ]; then
  # Server unreachable or error — fail silently
  exit 0
fi

exit 0
