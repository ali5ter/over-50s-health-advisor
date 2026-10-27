#!/usr/bin/env bash
#
# check-retain-staleness.sh — Detect on-disk health history that has NOT yet been retained into the
# Hindsight `health` bank, and say so. The retain path (retain-session.sh, backfill-history.sh) can
# miss sessions or metric groups — a subagent end that never fired, a backfill run before new
# sessions existed, a manifest not yet re-seeded — and until now that gap was invisible (#51). This
# makes it observable: it compares the local manifest against the on-disk history and METRICS_LOG.csv
# and reports what is still missing.
#
# Purely offline: it reads ~/.hindsight/retain-manifest.json and the on-disk files and makes no
# network call, so it is safe to run on every session end with no latency and no live server.
#
# Modes:
#   (no flag)     Hook mode: read agent_type from stdin, no-op for a non-advisor session (self-scoped
#                 like guard-bash-scope.sh), then print a terse warning to STDERR only when a gap
#                 exists. Registered on SubagentStop and Stop in hooks/hooks.json.
#   --from-hook   Same terse stderr path, forced, without reading stdin.
#   --report      Full human-readable report to STDOUT, for on-demand use.
#
# Gate: reports only when HINDSIGHT_RETAIN_ENABLED=true (sourced from ~/.hindsight/retain.env), the
# same enable gate as the retain path — if retention is off, staleness is a non-issue.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.0.0
# Date: 2026-10-26
# License: MIT
#
# Dependencies: bash 3.2+, jq, sed, awk, grep
#
# Exit codes:
#   0 - Always; a missing session must never block a session end or start.

set -euo pipefail

readonly ADVISOR_AGENT_TYPE="over-50s-health:advisor"

command -v jq >/dev/null 2>&1 || exit 0

# --- Args: --report prints a full report to stdout; --from-hook forces the terse stderr path. ---
MODE="hook"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --report)    MODE="report" ;;
    --from-hook) MODE="terse" ;;
    *) echo "check-retain-staleness.sh: unknown option '$1' (try --report or --from-hook)" >&2; exit 0 ;;
  esac
  shift
done

# --- Self-scope in hook mode: read agent_type from the hook's own stdin JSON (same as
# guard-bash-scope.sh / retain-session.sh). A plugin hook fires for every session on the machine,
# so a non-advisor session must no-op here.
if [[ "$MODE" == "hook" ]]; then
  input="$(cat)"
  agent_type="$(jq -r '.agent_type // empty' <<<"$input" 2>/dev/null || true)"
  [[ "$agent_type" == "$ADVISOR_AGENT_TYPE" ]] || exit 0
  MODE="terse"
fi

# --- Enable gate (same as retain-session.sh) ---
: "${HINDSIGHT_CONFIG:=$HOME/.hindsight/retain.env}"
if [ -f "$HINDSIGHT_CONFIG" ]; then
  # shellcheck disable=SC1090
  source "$HINDSIGHT_CONFIG"
fi
: "${HINDSIGHT_RETAIN_ENABLED:=false}"
[[ "$HINDSIGHT_RETAIN_ENABLED" == "true" ]] || exit 0

: "${CONTEXT_DIR:=$HOME/.claude/over-50s-health-advisor/context}"
: "${HINDSIGHT_MANIFEST:=$HOME/.hindsight/retain-manifest.json}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# Reduce any manifest id or on-disk path to a canonical key so the id spellings actually in the bank
# (absolute path, relative history/… path, and the old double-slash debris) compare equal to the
# on-disk paths: drop a leading "…/context/", collapse "///…/", strip a "#fragment" suffix.
norm() { sed -E 's#^.*/context/##; s#//+#/#g; s/#.*$//'; }

# The set of canonical keys already retained, one per line.
manifest_keys=""
if [ -f "$HINDSIGHT_MANIFEST" ]; then
  manifest_keys="$(jq -r '.[]' "$HINDSIGHT_MANIFEST" 2>/dev/null | norm)"
fi

# On-disk session files not represented by the manifest.
miss_sessions=()
total_sessions=0
have_sessions=0
if [[ -d "${CONTEXT_DIR}/history" ]]; then
  while IFS= read -r f; do
    base="$(basename "$f")"
    [[ "$base" == "INDEX.md" ]] && continue
    total_sessions=$((total_sessions + 1))
    key="$(printf '%s\n' "$f" | norm)"
    if grep -Fxq -- "$key" <<<"$manifest_keys"; then
      have_sessions=$((have_sessions + 1))
    else
      miss_sessions+=("$key")
    fi
  done < <(find "${CONTEXT_DIR}/history" -name '*.md' -type f 2>/dev/null)
fi

# METRICS_LOG.csv date-groups not represented by the manifest.
miss_metrics=()
total_metrics=0
have_metrics=0
metrics_file="${CONTEXT_DIR}/METRICS_LOG.csv"
if [ -f "$metrics_file" ]; then
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    total_metrics=$((total_metrics + 1))
    key="METRICS_LOG.csv:${d}"
    if grep -Fxq -- "$key" <<<"$manifest_keys"; then
      have_metrics=$((have_metrics + 1))
    else
      miss_metrics+=("$key")
    fi
  done < <(awk -F',' 'NR>1 && $1!="" {print $1}' "$metrics_file" | sort -u)
fi

miss_total=$(( ${#miss_sessions[@]} + ${#miss_metrics[@]} ))

if [[ $miss_total -eq 0 ]]; then
  if [[ "$MODE" == "report" ]]; then
    echo "Hindsight is caught up — all ${total_sessions} on-disk session file(s) and ${total_metrics} METRICS_LOG.csv date-group(s) are in the manifest."
  fi
  exit 0
fi

if [[ "$MODE" == "report" ]]; then
  echo "Hindsight retain staleness (offline, vs $(basename "$HINDSIGHT_MANIFEST")):"
  printf '  session files: %d on disk, %d retained, %d NOT yet retained\n' \
    "$total_sessions" "$have_sessions" "${#miss_sessions[@]}"
  if [[ ${#miss_sessions[@]} -gt 0 ]]; then
    for k in "${miss_sessions[@]}"; do echo "    - $k"; done
  fi
  printf '  metric groups: %d on disk, %d retained, %d NOT yet retained\n' \
    "$total_metrics" "$have_metrics" "${#miss_metrics[@]}"
  if [[ ${#miss_metrics[@]} -gt 0 ]]; then
    for k in "${miss_metrics[@]}"; do echo "    - $k"; done
  fi
  echo "  clear it:  bash ${REPO_ROOT}/scripts/backfill-history.sh   (idempotent; skips what is already retained)"
  exit 0
fi

# terse (hook) mode: one line to stderr, so a missed session is not silently dropped (#51).
printf 'Hindsight retain: %d session file(s) and %d METRICS_LOG.csv date-group(s) on disk are NOT yet retained — run "%s/scripts/backfill-history.sh" (idempotent), or check-retain-staleness.sh --report for the list.\n' \
  "${#miss_sessions[@]}" "${#miss_metrics[@]}" "$REPO_ROOT" >&2
exit 0
