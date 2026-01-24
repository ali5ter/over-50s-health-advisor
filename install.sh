#!/usr/bin/env bash

show_help() {
  cat <<'HELP'
Usage: ./install.sh [--User] [--force]

Installs the Over-50s Health Advisor Claude Code Agent.

Options:
  --User     Install to ~/.claude/agents (User scope)
  --force    Overwrite existing file without prompting
  --help     Show this help message
HELP
}

FORCE=0
SCOPE="project"

for arg in "$@"; do
  case "$arg" in
    --User)
      SCOPE="User"
      ;;
    --force)
      FORCE=1
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      show_help
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SRC="$ROOT_DIR/agent/over-50s-health-advisor.md"

if [[ ! -f "$AGENT_SRC" ]]; then
  echo "Agent source not found: $AGENT_SRC" >&2
  exit 1
fi

if [[ "$SCOPE" == "User" ]]; then
  DEST_DIR="$HOME/.claude/agents"
else
  DEST_DIR="$ROOT_DIR/.claude/agents"
fi

mkdir -p "$DEST_DIR"
DEST_FILE="$DEST_DIR/over-50s-health-advisor.md"

if [[ -f "$DEST_FILE" && "$FORCE" -ne 1 ]]; then
  read -r -p "File exists at $DEST_FILE. Overwrite? [y/N] " REPLY
  case "$REPLY" in
    [yY][eE][sS]|[yY])
      ;;
    *)
      echo "Install cancelled."
      exit 0
      ;;
  esac
fi

cp "$AGENT_SRC" "$DEST_FILE"
chmod 644 "$DEST_FILE"

if [[ "$SCOPE" == "User" ]]; then
  echo "Installed to User scope: $DEST_FILE"
else
  echo "Installed to project scope: $DEST_FILE"
fi
