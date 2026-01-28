#!/usr/bin/env bash

show_help() {
  cat <<'HELP'
Usage: ./install.sh [--project] [--force]

Installs the Over-50s Health Advisor Claude Code Agent.

By default, installs to user scope (~/.claude/agents) with context in
~/.claude/over-50s-health-advisor/context/, allowing the agent to work
from any directory.

Options:
  --project   Install to project scope (.claude/agents in this repo)
              Context files remain in context/user/ (for development)
  --force     Overwrite existing files without prompting
  --help      Show this help message

Examples:
  ./install.sh               # Install to user scope (recommended)
  ./install.sh --project     # Install to project scope (for development)
  ./install.sh --force       # Force install to user scope
HELP
}

FORCE=0
SCOPE="user"

for arg in "$@"; do
  case "$arg" in
    --project)
      SCOPE="project"
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

# Set paths based on scope
if [[ "$SCOPE" == "user" ]]; then
  AGENT_DEST="$HOME/.claude/agents/over-50s-health-advisor.md"
  CONTEXT_DIR="$HOME/.claude/over-50s-health-advisor/context"
else
  AGENT_DEST="$ROOT_DIR/.claude/agents/over-50s-health-advisor.md"
  CONTEXT_DIR="$ROOT_DIR/context/user"
fi

# Install agent definition
DEST_DIR="$(dirname "$AGENT_DEST")"
mkdir -p "$DEST_DIR"

if [[ -f "$AGENT_DEST" && "$FORCE" -ne 1 ]]; then
  read -r -p "File exists at $AGENT_DEST. Overwrite? [y/N] " REPLY
  case "$REPLY" in
    [yY][eE][sS]|[yY])
      ;;
    *)
      echo "Install cancelled."
      exit 0
      ;;
  esac
fi

cp "$AGENT_SRC" "$AGENT_DEST"
chmod 644 "$AGENT_DEST"

echo "✓ Installed agent to: $AGENT_DEST"

# For user scope: create context directory and copy templates if they don't exist
if [[ "$SCOPE" == "user" ]]; then
  mkdir -p "$CONTEXT_DIR"

  TEMPLATES=(
    "INITIAL_USER_INFORMATION.md"
    "CLIENT_HEALTH_CONTEXT.md"
    "CLIENT_PREFERENCES.md"
    "SESSION_NOTES.md"
    "SOURCES.md"
  )

  COPIED=0
  SKIPPED=0

  for template in "${TEMPLATES[@]}"; do
    DEST_FILE="$CONTEXT_DIR/$template"
    SRC_FILE="$ROOT_DIR/context/templates/$template"

    if [[ -f "$DEST_FILE" ]]; then
      SKIPPED=$((SKIPPED + 1))
    else
      if [[ -f "$SRC_FILE" ]]; then
        cp "$SRC_FILE" "$DEST_FILE"
        COPIED=$((COPIED + 1))
      else
        echo "Warning: Template not found: $SRC_FILE" >&2
      fi
    fi
  done

  echo "✓ Context directory: $CONTEXT_DIR"
  if [[ $COPIED -gt 0 ]]; then
    echo "  - Copied $COPIED template(s)"
  fi
  if [[ $SKIPPED -gt 0 ]]; then
    echo "  - Preserved $SKIPPED existing file(s)"
  fi

  echo ""
  echo "Installation complete!"
  echo ""
  echo "The agent can now be invoked from any directory."
  echo "Edit your context files at: $CONTEXT_DIR"
else
  echo ""
  echo "Installation complete (project scope)."
  echo ""
  echo "To use the agent, copy templates to context/user/:"
  echo "  cp -R context/templates/* context/user/"
fi
