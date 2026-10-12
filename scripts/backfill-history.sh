#!/usr/bin/env bash
# backfill-history.sh — Ingest all health history into the Hindsight `health` bank.
#
# Ingests:
#   - history/YYYY/YYYY-MM-DD.md (per-session files)
#   - CONTEXT_ARCHIVE.md (pre-v4.0.0 archive, rendered with date headers)
#   - _legacy/SESSION_NOTES_ARCHIVE.md (original archive)
#   - _legacy/SESSION_NOTES_DEEP_ARCHIVE.md (agent's deep archive workaround)
#   - METRICS_LOG.csv (rendered to prose before retaining)
#
# Idempotent: document IDs are derived from file paths + line ranges.
# Re-running on an already-populated bank produces no new documents (409 conflict).
#
# Usage:
#   ./scripts/backfill-history.sh              # defaults to 192.168.1.63
#   ./scripts/backfill-history.sh --host 10.0.0.1  # custom host
#   ./scripts/backfill-history.sh --dry-run      # show what would be sent
#
# Environment:
#   CONTEXT_DIR   — defaults to ~/.claude/over-50s-health-advisor/context
#   HINDSIGHT_URL — defaults to http://192.168.1.63:8888
#   HINDSIGHT_API_KEY — required; falls back to ~/.hindsight/api_key
#   HINDSIGHT_BANK  — defaults to health
#   BACKFILL_SKIP_LEGACY — set to "true" to skip _legacy/ files

set -euo pipefail

# --- Defaults ---
CONTEXT_DIR="${CONTEXT_DIR:-$HOME/.claude/over-50s-health-advisor/context}"
HINDSIGHT_URL="${HINDSIGHT_URL:-http://192.168.1.63:8888}"
HINDSIGHT_BANK="${HINDSIGHT_BANK:-health}"
DRY_RUN=false
SKIP_LEGACY="${BACKFILL_SKIP_LEGACY:-false}"

# --- Parse flags ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HINDSIGHT_URL="http://$2:8888"
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

# --- API key ---
if [ -z "${HINDSIGHT_API_KEY:-}" ]; then
  if [ -f ~/.hindsight/api_key ]; then
    HINDSIGHT_API_KEY=$(cat ~/.hindsight/api_key)
  fi
fi

if [ -z "${HINDSIGHT_API_KEY:-}" ]; then
  echo "Error: HINDSIGHT_API_KEY not set and ~/.hindsight/api_key not found." >&2
  exit 1
fi

# --- Helpers ---
# POST a document batch to Hindsight.
# Arguments:
#   $1 = JSON array of documents
# Returns: HTTP status code
post_documents() {
  local payload="$1"
  local http_code
  http_code=$(curl -s -w "%{http_code}" \
    -X POST "${HINDSIGHT_URL}/v1/${HINDSIGHT_BANK}/documents" \
    -H "Authorization: Bearer ${HINDSIGHT_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>/dev/null || echo "000")

  if [ "$http_code" = "200" ] || [ "$http_code" = "201" ] || [ "$http_code" = "409" ]; then
    echo "  OK (HTTP $http_code)" >&2
    return 0
  else
    echo "  FAIL (HTTP $http_code)" >&2
    return 1
  fi
}

# Ingest a file by splitting on date headers (## YYYY-MM-DD).
# Writes JSON documents to stdout, one per section.
# Arguments:
#   $1 = file path
#   $2 = label prefix for document IDs (e.g. "CONTEXT_ARCHIVE.md")
ingest_by_date_header() {
  local file="$1"
  local label="$2"
  local tmpfile
  tmpfile=$(mktemp)

  # Split file into sections by date headers, write to temp file.
  # Each section is prefixed with an "@@@DATE YYYY-MM-DD" marker so the reader
  # can recover the date without re-parsing the header line.
  awk '
    /^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ {
      d = $0
      sub(/^## /, "", d)
      d = substr(d, 1, 10)
      print "@@@DATE " d
      started = 1
      print
      next
    }
    started { print }
  ' "$file" > "$tmpfile"

  # Process sections from temp file. Human-readable diagnostics (dry-run
  # markers and post_documents OK/FAIL lines) go to stderr, so the only thing
  # on stdout is the final "count errors" summary the caller captures.
  local current_date=""
  local current_content=""
  local section_count=0
  local errors=0
  local line doc_id payload

  while IFS= read -r line; do
    case "$line" in
      "@@@DATE "*)
        if [ -n "$current_date" ]; then
          section_count=$((section_count + 1))
          doc_id="${label}:${current_date}"
          if [ "$DRY_RUN" = true ]; then
            echo "  [DRY RUN] $doc_id" >&2
          else
            payload=$(jq -nc --arg id "$doc_id" --arg content "$current_content" \
              --arg date "$current_date" \
              '{id: $id, content: $content, metadata: {date: $date}}')
            if ! post_documents "$payload"; then
              errors=$((errors + 1))
            fi
          fi
        fi
        current_date="${line#@@@DATE }"
        current_content=""
        ;;
      *)
        if [ -n "$current_content" ]; then
          current_content="${current_content}
${line}"
        else
          current_content="$line"
        fi
        ;;
    esac
  done < "$tmpfile"

  # Flush last section
  if [ -n "$current_date" ]; then
    section_count=$((section_count + 1))
    doc_id="${label}:${current_date}"
    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY RUN] $doc_id" >&2
    else
      payload=$(jq -nc --arg id "$doc_id" --arg content "$current_content" \
        --arg date "$current_date" \
        '{id: $id, content: $content, metadata: {date: $date}}')
      if ! post_documents "$payload"; then
        errors=$((errors + 1))
      fi
    fi
  fi

  rm -f "$tmpfile"
  echo "${section_count} ${errors}"
}

# --- Ingest per-session history files ---
echo "=== Per-session history ==="
SESSION_COUNT=0
ERRORS=0

for year_dir in "$CONTEXT_DIR"/history/*/; do
  [ -d "$year_dir" ] || continue

  for session_file in "$year_dir"/*.md; do
    [ -f "$session_file" ] || continue
    # Skip the master index — it is not a session, just lives in the year dir.
    if [ "$(basename "$session_file")" = "INDEX.md" ]; then
      continue
    fi
    SESSION_COUNT=$((SESSION_COUNT + 1))

    # Extract date from frontmatter or filename
    doc_date=$(jq -r '.date // empty' "$session_file" 2>/dev/null || echo "")
    if [ -z "$doc_date" ]; then
      doc_date=$(basename "$session_file" .md)
    fi

    # Document ID: file path (unique, idempotent)
    doc_id="$session_file"
    content=$(cat "$session_file")

    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY RUN] $doc_id (date: $doc_date)"
      continue
    fi

    payload=$(jq -nc --arg id "$doc_id" --arg content "$content" --arg date "$doc_date" \
      '{id: $id, content: $content, metadata: {date: $date}}')

    if ! post_documents "$payload"; then
      ERRORS=$((ERRORS + 1))
    fi
  done
done

echo "  $SESSION_COUNT session files processed"

# --- Ingest CONTEXT_ARCHIVE.md ---
echo "=== CONTEXT_ARCHIVE.md ==="
if [ -f "$CONTEXT_DIR/CONTEXT_ARCHIVE.md" ]; then
  result=$(ingest_by_date_header "$CONTEXT_DIR/CONTEXT_ARCHIVE.md" "CONTEXT_ARCHIVE.md")
  archive_count=$(echo "$result" | awk '{print $1}')
  archive_errors=$(echo "$result" | awk '{print $2}')
  ERRORS=$((ERRORS + archive_errors))
  echo "  $archive_count sections processed"
fi

# --- Ingest _legacy/ files ---
echo "=== _legacy/ archives ==="
if [ "$SKIP_LEGACY" != "true" ] && [ -d "$CONTEXT_DIR/_legacy" ]; then
  for legacy_file in "$CONTEXT_DIR/_legacy/SESSION_NOTES_ARCHIVE.md" \
                      "$CONTEXT_DIR/_legacy/SESSION_NOTES_DEEP_ARCHIVE.md"; do
    [ -f "$legacy_file" ] || continue

    FILENAME=$(basename "$legacy_file")
    result=$(ingest_by_date_header "$legacy_file" "$FILENAME")
    file_count=$(echo "$result" | awk '{print $1}')
    file_errors=$(echo "$result" | awk '{print $2}')
    ERRORS=$((ERRORS + file_errors))
    echo "  $FILENAME: $file_count sections processed"
  done
fi

# --- Ingest METRICS_LOG.csv ---
echo "=== METRICS_LOG.csv ==="
METRICS_FILE="$CONTEXT_DIR/METRICS_LOG.csv"
if [ -f "$METRICS_FILE" ]; then
  # Group CSV rows by date, render as prose
  tmpfile=$(mktemp)

  awk -F',' '
    NR == 1 { next }  # skip header
    {
      date = $1
      metric = $2
      value = $3
      unit = $4
      note = $5
      if (date != prev_date && prev_date != "") {
        print "---DATE---"
        print prev_date ": " prose
      }
      prose = prose (prose ? "; " : "") metric " " value " " unit (note ? " (" note ")" : "")
      prev_date = date
    }
    END {
      if (prev_date != "") {
        print "---DATE---"
        print prev_date ": " prose
      }
    }
  ' "$METRICS_FILE" > "$tmpfile"

  metrics_count=0
  metrics_errors=0

  # The awk emits a "---DATE---" marker before each "date: prose" line. Skip
  # the marker and treat each "date: prose" line as one group, pulling the date
  # from the part before the first colon.
  while IFS= read -r line; do
    if [ "$line" = "---DATE---" ] || [ -z "$line" ]; then
      continue
    fi
    current_date="${line%%:*}"
    doc_id="METRICS_LOG.csv:$current_date"
    metrics_count=$((metrics_count + 1))

    if [ "$DRY_RUN" = true ]; then
      echo "  [DRY RUN] $doc_id" >&2
    else
      payload=$(jq -nc --arg id "$doc_id" --arg content "$line" \
        --arg date "$current_date" \
        '{id: $id, content: $content, metadata: {date: $date}}')
      if ! post_documents "$payload"; then
        metrics_errors=$((metrics_errors + 1))
      fi
    fi
  done < "$tmpfile"

  rm -f "$tmpfile"
  ERRORS=$((ERRORS + metrics_errors))
  echo "  $metrics_count date groups processed"
fi

echo ""
echo "=== Done ==="
if [ "$DRY_RUN" = true ]; then
  echo "  Total: $SESSION_COUNT session files + archives to ingest"
else
  echo "  Total: $SESSION_COUNT session files + archives ingested"
fi
if [ "$ERRORS" -gt 0 ]; then
  echo "  Errors: $ERRORS (check above for failed documents)"
  exit 1
fi
exit 0
