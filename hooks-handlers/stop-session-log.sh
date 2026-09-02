#!/usr/bin/env bash
#
# stop-session-log.sh - Stop hook: gate session-end logging to the advisor agent
#
# hooks/hooks.json has no way to scope a hook to one agent declaratively (no matcher/if
# support for agent identity, and Stop has no matcher support at all), so this hook fires
# on every session's exit, not just the advisor's. Previously this gate was done inside a
# "type": "prompt" hook — the agent_type check itself was just text in the prompt body,
# asking the model to decide whether to act. That check could never actually resolve (a
# Stop hook has no $ARGUMENTS substitution the way a slash command does) and, worse, made
# the gate a plain-text claim inside the same untrusted block it was meant to guard —
# indistinguishable from any other text that shows up in context and asks the model to
# write to SESSION_NOTES.md/METRICS_LOG.csv or POST an Insight. This script moves the gate
# to bash, mirroring guard-bash-scope.sh: agent_type is read from the hook's own stdin
# JSON before any model involvement, so nothing the model reads in-conversation can spoof
# it into passing.
#
# When the gate passes, this script emits {"decision":"block","reason":...} — the reason
# text becomes the model's instructions for actually writing the session summary, metrics,
# and (optionally) posting a Portal Insight, since composing that summary needs the model.
# Only the yes/no of whether those instructions are shown at all is decided in bash.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.0.0
# Date: 2026-09-02
# License: MIT
#
# Usage: Registered as a Stop hook in the plugin's hooks/hooks.json. Not intended to be
#   run standalone, but can be exercised with:
#     echo '{"agent_type":"over-50s-health:advisor"}' | ./stop-session-log.sh
#
# Dependencies: bash 4.0+, jq
#
# Exit codes:
#   0 - Always; the decision is communicated via stdout JSON, not the exit code

set -euo pipefail

readonly ADVISOR_AGENT_TYPE="over-50s-health:advisor"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"

agent_type="$(jq -r '.agent_type // empty' <<<"$input")"
[[ "$agent_type" == "$ADVISOR_AGENT_TYPE" ]] || exit 0

# shellcheck disable=SC2016  # single-quoted on purpose — $PORTAL_URL/$INSIGHTS_TOKEN stay
# literal here; the model substitutes them when it actually runs the curl command later.
reason='Before ending this over-50s-health:advisor session: (1) append a brief dated summary to ~/.claude/over-50s-health-advisor/context/SESSION_NOTES.md — today'\''s date, key topics discussed, any new observations, and action items; append only, never overwrite existing content. (2) If any quantifiable metric was mentioned or updated this session (weight, body composition, vitals, sleep, labs, nutrition, activity, etc.), append one CSV row per metric to ~/.claude/over-50s-health-advisor/context/METRICS_LOG.csv in the form date,metric,value,unit,note — append only, never overwrite existing rows. (3) If this session surfaced something genuinely new or notable in '\''Current metrics'\'' or '\''Active watch items'\'' (not every session does), check whether ~/.claude/over-50s-health-advisor/.env exists and defines PORTAL_URL and INSIGHTS_TOKEN (KEY=VALUE lines); if either is missing, skip this step silently — Personal Health Portal integration is optional. Otherwise: write a concise 1-3 sentence Insight body summarising what changed and why it matters; set metricGroup to vitals, hume, or oura_sleep if the Insight is specifically about that metric group, or omit it (null) for a cross-source observation; set periodStart/periodEnd to the date range the Insight covers (YYYY-MM-DD; the same date for both for a single-day observation); write the JSON payload {"body":...,"metricGroup":...,"periodStart":...,"periodEnd":...} to a temp file; run: curl -s -X POST "$PORTAL_URL/api/insights" -H "Authorization: Bearer $INSIGHTS_TOKEN" -H "Content-Type: application/json" -d @<temp file path>; then delete the temp file.'

jq -n --arg r "$reason" '{decision: "block", reason: $r}'
exit 0
