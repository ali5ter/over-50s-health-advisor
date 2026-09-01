#!/usr/bin/env bash
#
# guard-bash-scope.sh - PreToolUse hook: scope the advisor agent's Bash access
#
# The advisor agent has Bash to run local health-export scripts and read metric files, but it
# also has broad Write access to a directory holding a year of personal health history. This
# hook is the boundary that stops that combination from becoming a way to delete, relocate, or
# transmit that data: destructive commands and generic network egress (curl/wget/nc) are denied
# outright, except the one curl shape the Personal Health Portal integration needs (see the
# README's "Personal Health Portal integration" section), which is allowed only when the command
# matches that shape exactly. Read-only analysis tools not already in Claude Code's built-in
# read-only set, the health export scripts, and gh issue/pr filing are allowed so they don't
# prompt on every session.
#
# The curl allow rule trusts that $PORTAL_URL wasn't reassigned earlier in this session's shell
# — it isn't re-resolved from .env at match time. That is an accepted gap for a single-user tool,
# not a hard security boundary against an adversarial actor.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.1.0
# Date: 2026-09-01
# License: MIT
#
# Usage: Registered as a PreToolUse hook on Bash in the plugin's hooks/hooks.json, which is
#   the only place a plugin can attach hooks — Claude Code silently ignores a `hooks:` key
#   in plugin agent frontmatter (confirmed 2026-09-01; see agents/advisor.md history for the
#   prior, non-functional placement). Because hooks/hooks.json applies plugin-wide rather than
#   per-agent, this script self-scopes by checking `agent_type` in its own input and is a no-op
#   for every session except an active over-50s-health:advisor one. Not intended to be run
#   standalone, but can be exercised with:
#     echo '{"agent_type":"over-50s-health:advisor","tool_input":{"command":"rm -rf ~/.claude/over-50s-health-advisor"}}' \
#       | ./guard-bash-scope.sh
#
# Dependencies: bash 4.0+, jq
#
# Exit codes:
#   0 - Always; the permission decision is communicated via stdout JSON, not the exit code

set -euo pipefail

readonly ADVISOR_AGENT_TYPE="over-50s-health:advisor"

command -v jq >/dev/null 2>&1 || exit 0

input="$(cat)"

# hooks/hooks.json has no way to scope a hook to one agent declaratively (no matcher/if support
# for agent identity), so every other session on this machine also invokes this script on every
# Bash call. Stay silent immediately for anything that isn't the advisor agent.
agent_type="$(jq -r '.agent_type // empty' <<<"$input")"
[[ "$agent_type" == "$ADVISOR_AGENT_TYPE" ]] || exit 0

command_str="$(jq -r '.tool_input.command // empty' <<<"$input")"
[[ -n "$command_str" ]] || exit 0

# Emit a PreToolUse permission decision and exit.
# @param $1  permissionDecision value: allow, deny, or ask
# @param $2  Human-readable reason shown to Claude or the user
# @return never returns; exits 0 after printing JSON
decide() {
    local decision="$1" reason="$2"
    jq -n --arg d "$decision" --arg r "$reason" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
    exit 0
}

# Destructive or privilege-escalating commands: no legitimate use for this agent.
if grep -qE '(^|[;&|]|\s)(rm|rmdir|mv|sudo|chmod|chown|dd)(\s|$)' <<<"$command_str"; then
    decide "deny" "Destructive/privileged command denied for the health advisor agent — it has no business deleting, relocating, or re-permissioning files."
fi
if grep -qE '(^|[;&|]|\s)git\s+push\s+.*--force' <<<"$command_str"; then
    decide "deny" "Force-push denied for the health advisor agent."
fi

# Generic network egress: the difference between reading health history and transmitting it.
if grep -qE '(^|[;&|]|\s)(wget|nc|ncat|netcat)(\s|$)' <<<"$command_str"; then
    decide "deny" "Network egress via this command is denied for the health advisor agent."
fi

if grep -qE '(^|[;&|]|\s)curl(\s|$)' <<<"$command_str"; then
    # Only the exact Personal Health Portal insights POST is allowed. Anything else — extra
    # flags, a different path, a hardcoded host, or trailing chained commands — is denied.
    # shellcheck disable=SC2016  # single-quoted on purpose — the regex matches literal $ characters
    portal_pattern='^curl -s -X POST "\$PORTAL_URL/api/insights" -H "Authorization: Bearer \$INSIGHTS_TOKEN" -H "Content-Type: application/json" -d @[^[:space:]]+$'
    if grep -qE "$portal_pattern" <<<"$command_str"; then
        decide "allow" "Matches the Personal Health Portal insights POST shape."
    fi
    decide "deny" "curl is denied for the health advisor agent except the exact Personal Health Portal insights POST."
fi

# Read-only analysis tools not already in Claude Code's built-in read-only set (which already
# covers ls, cat, grep, head, tail, wc, find, and read-only git).
if grep -qE '(^|[;&|]|\s)(awk|sed|sort|uniq|cut)(\s|$)' <<<"$command_str"; then
    decide "allow" "Read-only analysis command."
fi
if grep -qE '(^|[;&|]|\s)unzip\s+-p(\s|$)' <<<"$command_str"; then
    decide "allow" "Streaming unzip -p is read-only."
fi

# The health tooling itself, and issue/PR filing.
if grep -qE '(^|[;&|]|\s)~/Dropbox/Private/Home/Health/scripts/' <<<"$command_str"; then
    decide "allow" "Health tooling script."
fi
if grep -qE '(^|[;&|]|\s)gh\s+(issue|pr)(\s|$)' <<<"$command_str"; then
    decide "allow" "Issue/PR filing."
fi

# Anything else falls through to the normal permission flow (session permissionMode / prompt).
exit 0
