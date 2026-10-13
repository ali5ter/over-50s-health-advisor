#!/usr/bin/env bash
# backfill-history.sh — Ingest all health history into the Hindsight `health` bank.
#
# Retention goes through the MCP `retain` tool via hindsight-retain.py — the transport
# the server actually exposes. The old REST POST /v1/{bank}/documents 404s: the server
# speaks MCP at /mcp/{bank}/ and its REST API has no "create document" route.
#
# Ingests:
#   - history/YYYY/YYYY-MM-DD.md  (per-session files; the master INDEX.md is skipped)
#   - CONTEXT_ARCHIVE.md          (pre-v4.0.0 archive, split on ## YYYY-MM-DD headers)
#   - _legacy/SESSION_NOTES_ARCHIVE.md, _legacy/SESSION_NOTES_DEEP_ARCHIVE.md
#   - METRICS_LOG.csv             (grouped by date, rendered to prose)
#
# Idempotent: hindsight-retain.py keeps a local manifest of retained document ids and
# skips them on re-run. A real run first --seeds the manifest from the bank's current
# ids, so a fresh machine does not re-add documents that are already present.
#
# Usage:
#   ./scripts/backfill-history.sh                 # defaults to 192.168.1.63
#   ./scripts/backfill-history.sh --host 10.0.0.1 # custom host
#   ./scripts/backfill-history.sh --dry-run        # show what would be retained
#   ./scripts/backfill-history.sh --skip-legacy    # skip _legacy/ archives
#
# Environment:
#   CONTEXT_DIR       — defaults to ~/.claude/over-50s-health-advisor/context
#   HINDSIGHT_BANK    — bank name, default "health" (see hindsight-retain.py)
#   HINDSIGHT_API_KEY — required; falls back to ~/.hindsight/api_key
#   BACKFILL_SKIP_LEGACY — set to "true" to skip _legacy/ files

set -euo pipefail

# --- Defaults ---
CONTEXT_DIR="${CONTEXT_DIR:-$HOME/.claude/over-50s-health-advisor/context}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RETAIN="$SCRIPT_DIR/hindsight-retain.py"
DRY_RUN=false
SKIP_LEGACY="${BACKFILL_SKIP_LEGACY:-false}"
HOST=""

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --skip-legacy)
      SKIP_LEGACY=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--host HOST] [--dry-run] [--skip-legacy]" >&2
      exit 1
      ;;
  esac
done

# --- API key (fail early with an actionable message; the helper re-checks) ---
if [ -z "${HINDSIGHT_API_KEY:-}" ] && [ ! -f ~/.hindsight/api_key ]; then
  echo "Error: HINDSIGHT_API_KEY not set and ~/.hindsight/api_key not found." >&2
  exit 1
fi

# NDJSON accumulator of documents to retain (id, content, date, tags).
NDJSON="$(mktemp)"
trap 'rm -f "$NDJSON"' EXIT

# Emit one document as an NDJSON line. In dry-run, just name it on stderr.
emit() {
  if [ "$DRY_RUN" = true ]; then
    echo "  [DRY RUN] $1" >&2
  else
    jq -nc --arg id "$1" --arg content "$2" --arg date "$3" --arg tag "$4" \
      '{id: $id, content: $content, date: $date, tags: [$tag]}' >> "$NDJSON"
  fi
}

# Split a file on "## YYYY-MM-DD" headers and emit one document per section.
# Args: $1 = file, $2 = label. Prints the section count (the only thing on stdout).
emit_by_date_header() {
  local file="$1" label="$2"
  local tmp cur_date="" cur_content="" count=0 line
  tmp="$(mktemp)"

  awk '
    /^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ {
      d = $0; sub(/^## /, "", d); d = substr(d, 1, 10)
      print "@@@DATE " d; started = 1; print; next
    }
    started { print }
  ' "$file" > "$tmp"

  while IFS= read -r line; do
    case "$line" in
      "@@@DATE "*)
        if [ -n "$cur_date" ]; then
          emit "${label}:${cur_date}" "$cur_content" "$cur_date" "archive"
          count=$((count + 1))
        fi
        cur_date="${line#@@@DATE }"
        cur_content=""
        ;;
      *)
        if [ -n "$cur_content" ]; then
          cur_content="${cur_content}
${line}"
        else
          cur_content="$line"
        fi
        ;;
    esac
  done < "$tmp"

  if [ -n "$cur_date" ]; then
    emit "${label}:${cur_date}" "$cur_content" "$cur_date" "archive"
    count=$((count + 1))
  fi

  rm -f "$tmp"
  echo "$count"
}

# --- Per-session history ---
echo "=== Per-session history ==="
SESSION_COUNT=0
for year_dir in "$CONTEXT_DIR"/history/*/; do
  [ -d "$year_dir" ] || continue
  for session_file in "$year_dir"/*.md; do
    [ -f "$session_file" ] || continue
    # Skip the master index — it lives in the year dir but is not a session.
    if [ "$(basename "$session_file")" = "INDEX.md" ]; then
      continue
    fi
    SESSION_COUNT=$((SESSION_COUNT + 1))
    doc_date=$(jq -r '.date // empty' "$session_file" 2>/dev/null || echo "")
    [ -z "$doc_date" ] && doc_date=$(basename "$session_file" .md)
    emit "$session_file" "$(cat "$session_file")" "$doc_date" "session"
  done
done
echo "  $SESSION_COUNT session files"

# --- CONTEXT_ARCHIVE.md ---
ARCHIVE_COUNT=0
echo "=== CONTEXT_ARCHIVE.md ==="
if [ -f "$CONTEXT_DIR/CONTEXT_ARCHIVE.md" ]; then
  ARCHIVE_COUNT=$(emit_by_date_header "$CONTEXT_DIR/CONTEXT_ARCHIVE.md" "CONTEXT_ARCHIVE.md")
  echo "  $ARCHIVE_COUNT sections"
fi

# --- _legacy/ archives ---
echo "=== _legacy/ archives ==="
if [ "$SKIP_LEGACY" != "true" ] && [ -d "$CONTEXT_DIR/_legacy" ]; then
  for legacy_file in "$CONTEXT_DIR/_legacy/SESSION_NOTES_ARCHIVE.md" \
                     "$CONTEXT_DIR/_legacy/SESSION_NOTES_DEEP_ARCHIVE.md"; do
    [ -f "$legacy_file" ] || continue
    filename=$(basename "$legacy_file")
    legacy_count=$(emit_by_date_header "$legacy_file" "$filename")
    ARCHIVE_COUNT=$((ARCHIVE_COUNT + legacy_count))
    echo "  $filename: $legacy_count sections"
  done
fi

# --- METRICS_LOG.csv ---
echo "=== METRICS_LOG.csv ==="
METRICS_FILE="$CONTEXT_DIR/METRICS_LOG.csv"
METRICS_COUNT=0
if [ -f "$METRICS_FILE" ]; then
  metrics_tmp="$(mktemp)"
  awk -F',' '
    NR == 1 { next }
    {
      date = $1; metric = $2; value = $3; unit = $4; note = $5
      if (date != prev_date && prev_date != "") {
        print "---DATE---"; print prev_date ": " prose
      }
      prose = prose (prose ? "; " : "") metric " " value " " unit (note ? " (" note ")" : "")
      prev_date = date
    }
    END { if (prev_date != "") { print "---DATE---"; print prev_date ": " prose } }
  ' "$METRICS_FILE" > "$metrics_tmp"

  while IFS= read -r line; do
    if [ "$line" = "---DATE---" ] || [ -z "$line" ]; then
      continue
    fi
    current_date="${line%%:*}"
    content="${line#*: }"
    emit "METRICS_LOG.csv:$current_date" "$content" "$current_date" "metrics"
    METRICS_COUNT=$((METRICS_COUNT + 1))
  done < "$metrics_tmp"
  rm -f "$metrics_tmp"
  echo "  $METRICS_COUNT date groups"
fi

# --- Retain (or show) ---
echo ""
echo "=== Done ==="
echo "  $SESSION_COUNT sessions + $ARCHIVE_COUNT archive sections + $METRICS_COUNT metric groups"

if [ "$DRY_RUN" = true ]; then
  echo "  --dry-run: nothing was sent. Re-run without --dry-run to retain."
  exit 0
fi

run_retain() {
  if [ -n "$HOST" ]; then
    python3 "$RETAIN" "$@" --host "$HOST"
  else
    python3 "$RETAIN" "$@"
  fi
}

# Seed the manifest from the bank first so existing documents are not re-added.
run_retain --seed
# Then retain everything new.
if [ -s "$NDJSON" ]; then
  run_retain --stdin < "$NDJSON"
else
  echo "  no new documents to retain"
fi
