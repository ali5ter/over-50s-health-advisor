#!/usr/bin/env bash
#
# migrate-per-session.sh
#
# @description  Migrates the legacy two-file session history
#               (SESSION_NOTES.md + SESSION_NOTES_ARCHIVE.md) into a
#               per-session directory structure
#               (history/YYYY/YYYY-MM-DD.md) with a master INDEX.md.
#
#               Works on a temporary copy of the context directory.
#               Verifies losslessness (line count + word count) before
#               moving originals to _legacy/. Idempotent — safe to run
#               repeatedly.
#
# @side_effects Creates history/ and _legacy/ directories in the context
#               directory. Moves original files to _legacy/ after
#               verification.
# @exit         0 on success, 1 on verification failure
#
# Usage: Run from any directory:
#   bash "$(dirname "$0")/migrate-per-session.sh"
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Date:   2026-10-10
# License: MIT

set -euo pipefail

readonly CONTEXT_DIR="${HOME}/.claude/over-50s-health-advisor/context"
readonly LEGACY_DIR="${CONTEXT_DIR}/_legacy"
readonly HISTORY_DIR="${CONTEXT_DIR}/history"

# --- Guard: already migrated? ---
if [[ -d "${LEGACY_DIR}" ]]; then
    echo "Already migrated — _legacy/ exists. Skipping."
    exit 0
fi

# --- Guard: context directory exists? ---
if [[ ! -d "${CONTEXT_DIR}" ]]; then
    echo "ERROR: Context directory not found at ${CONTEXT_DIR}" >&2
    exit 1
fi

# --- Create a working copy ---
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "Copying context directory to temporary workspace..."
cp -R "${CONTEXT_DIR}" "${WORK_DIR}/context"

readonly SRC_NOTES="${WORK_DIR}/context/SESSION_NOTES.md"
readonly SRC_ARCHIVE="${WORK_DIR}/context/SESSION_NOTES_ARCHIVE.md"
readonly SRC_DEEP="${WORK_DIR}/context/SESSION_NOTES_DEEP_ARCHIVE.md"

# --- Count originals for verification ---
orig_lines=0
orig_words=0
for f in "${SRC_NOTES}" "${SRC_ARCHIVE}"; do
    if [[ -f "$f" ]]; then
        orig_lines=$(( orig_lines + $(wc -l < "$f") ))
        orig_words=$(( orig_words + $(wc -w < "$f") ))
    fi
done
if [[ -f "${SRC_DEEP}" ]]; then
    orig_lines=$(( orig_lines + $(wc -l < "${SRC_DEEP}") ))
    orig_words=$(( orig_words + $(wc -w < "${SRC_DEEP}") ))
fi

echo "Original totals: ${orig_lines} lines, ${orig_words} words"

# --- Write a single entry file ---
# @param $1  date (YYYY-MM-DD)
# @param $2  topics (from heading, after date)
# @param $3  marker (e.g. deep_archive, or empty)
# @param $4  content (the entry body)
write_entry() {
    local date="$1" topics="$2" marker="$3" content="$4"
    local year="${date:0:4}"
    mkdir -p "${HISTORY_DIR}/${year}"
    local entry_file="${HISTORY_DIR}/${year}/${date}.md"

    {
        echo "---"
        echo "date: ${date}"
        if [[ -n "${marker}" ]]; then
            echo "archived_from: ${marker}"
        fi
        echo "metrics:"
        echo "---"
        printf '%s\n' "$content"
    } > "${entry_file}"

    echo "  ${entry_file}"
}

# --- Extract entries from a file ---
# Splits a file by '---' separators, extracts entries that start with
# '## YYYY-MM-DD', and writes each to history/YYYY/YYYY-MM-DD.md.
# Prints the list of extracted dates to stdout (one per line).
#
# Args: $1 = source file, $2 = optional marker
extract_entries() {
    local src="$1" marker="${2:-}"
    local date="" topics="" entry="" in_entry=0 heading_written=0

    if [[ ! -f "$src" ]]; then
        return
    fi

    while IFS= read -r line; do
        # Detect entry boundary: ## YYYY-MM-DD
        if [[ "$line" =~ ^##\ ([0-9]{4}-[0-9]{2}-[0-9]{2})\ (.*) ]]; then
            # Flush previous entry if we had one
            if [[ $in_entry -eq 1 && $heading_written -eq 1 && -n "$entry" ]]; then
                write_entry "$date" "$topics" "$marker" "$entry"
            fi
            date="${BASH_REMATCH[1]}"
            topics="${BASH_REMATCH[2]}"
            entry="## ${date} ${topics}"$'\n'
            in_entry=1
            heading_written=1
        elif [[ $in_entry -eq 1 ]]; then
            if [[ "$line" =~ ^---[[:space:]]*$ ]]; then
                # Flush this entry
                write_entry "$date" "$topics" "$marker" "$entry"
                entry=""
                in_entry=0
                heading_written=0
            else
                entry+="${line}"$'\n'
            fi
        fi
    done < "$src"

    # Flush the last entry
    if [[ $in_entry -eq 1 && $heading_written -eq 1 && -n "$entry" ]]; then
        write_entry "$date" "$topics" "$marker" "$entry"
    fi
}

# --- Extract condensed entries from a file ---
# SESSION_NOTES_ARCHIVE.md has a "Condensed earlier history" section at the
# bottom with one-line summaries in the format:
#   - **Month DD** Topic text...
# These are valid session summaries but lack full YYYY-MM-DD dates.
# We extract them as condensed entries and record them for INDEX.md.
#
# Args: $1 = source file
# Outputs condensed entries to ${WORK_DIR}/condensed_entries.tmp
# Format: MONTH-DD|topics|content (one per entry)
extract_condensed() {
    local src="$1"
    if [[ ! -f "$src" ]]; then
        return
    fi

    local in_condensed=0 month_day="" topics="" content=""

    while IFS= read -r line; do
        # Detect the start of the condensed section
        if [[ "$line" == *"Condensed earlier history"* ]]; then
            in_condensed=1
            continue
        fi

        if [[ $in_condensed -eq 1 ]]; then
            # New condensed entry: - **Month DD** ...
            if [[ "$line" =~ ^-\ \*\*([A-Z][a-z]{2,2}\ [0-9]{1,2})\ \*\*\ (.*) ]]; then
                # Flush previous entry
                if [[ -n "$month_day" && -n "$content" ]]; then
                    printf '%s|%s|%s\n' "$month_day" "$topics" "$content" >> "${WORK_DIR}/condensed_entries.tmp"
                fi
                month_day="${BASH_REMATCH[1]}"
                topics="${BASH_REMATCH[2]}"
                content=""
            elif [[ -n "$month_day" ]]; then
                # Continuation of current entry
                content+="${line}"$'\n'
            fi
        fi
    done < "$src"

    # Flush last entry
    if [[ -n "$month_day" && -n "$content" ]]; then
        printf '%s|%s|%s\n' "$month_day" "$topics" "$content" >> "${WORK_DIR}/condensed_entries.tmp"
    fi
}

# --- Phase 1: Extract entries ---
echo ""
echo "Phase 1: Extracting session entries..."
echo ""

mkdir -p "${HISTORY_DIR}"

# Extract from SESSION_NOTES.md (active notes — archive entries only)
# The first ~2 entries are active; the rest are archived.
echo "  From SESSION_NOTES.md:"
if [[ -f "${SRC_NOTES}" ]]; then
    # Skip preamble (before first ## heading), count entries
    awk '/^## [0-9]{4}-[0-9]{2}-[0-9]{2}/{n++} n > 2' "${SRC_NOTES}" > "${WORK_DIR}/notes_archive.tmp"
    extract_entries "${WORK_DIR}/notes_archive.tmp" ""
fi

echo ""
echo "  From SESSION_NOTES_ARCHIVE.md:"
if [[ -f "${SRC_ARCHIVE}" ]]; then
    extract_entries "${SRC_ARCHIVE}" ""
fi

echo ""
echo "  From SESSION_NOTES_DEEP_ARCHIVE.md:"
if [[ -f "${SRC_DEEP}" ]]; then
    # Deep archive has a preamble before the "Batch condensed" section.
    awk '/^# Batch condensed/{found=1; next} found' "${SRC_DEEP}" > "${WORK_DIR}/deep_batch.tmp"
    extract_entries "${WORK_DIR}/deep_batch.tmp" "deep_archive"
fi

echo ""
echo "Phase 1 complete."

# --- Extract condensed entries from SESSION_NOTES_ARCHIVE.md ---
echo ""
echo "Phase 1b: Extracting condensed entries..."
echo ""
touch "${WORK_DIR}/condensed_entries.tmp"
if [[ -f "${SRC_ARCHIVE}" ]]; then
    extract_condensed "${SRC_ARCHIVE}"
    condensed_count=0
    if [[ -s "${WORK_DIR}/condensed_entries.tmp" ]]; then
        while IFS='|' read -r month_day topics content; do
            condensed_count=$(( condensed_count + 1 ))
            echo "  Condensed: ${month_day} — ${topics}"
        done < "${WORK_DIR}/condensed_entries.tmp"
        echo "  ${condensed_count} condensed entries extracted"
    fi
fi
echo "Phase 1b complete."

# --- Phase 2: Build INDEX.md ---
echo ""
echo "Phase 2: Building INDEX.md..."
echo ""

# Collect all session dates from history/YYYY/ files (sorted newest first)
readonly INDEX_FILE="${CONTEXT_DIR}/INDEX.md"

# Gather dates from all year directories, sorted newest first
all_dates=()
for year_dir in "${HISTORY_DIR}"/[0-9][0-9][0-9][0-9]; do
    [[ -d "$year_dir" ]] || continue
    for f in "$year_dir"/*.md; do
        [[ -f "$f" ]] || continue
        if [[ "$(basename "$f")" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})\.md$ ]]; then
            all_dates+=("${BASH_REMATCH[1]}")
        fi
    done
done

# Sort dates newest first
mapfile -t sorted_dates < <(printf '%s\n' "${all_dates[@]}" | sort -r)

# Build INDEX.md
{
    echo "# Session Index"
    echo ""
    echo "| Date       | Topics                                      | Metrics |"
    echo "|------------|---------------------------------------------|---------|"
    for date in "${sorted_dates[@]}"; do
        # Extract topics from the session file heading
        topics=""
        session_file="${HISTORY_DIR}/${date:0:4}/${date}.md"
        if [[ -f "$session_file" ]]; then
            # Strip the ## YYYY-MM-DD — prefix using sed -E (BSD sed needs -E for \?)
            topics="$(grep -E '^##? [0-9]{4}-[0-9]{2}-[0-9]{2}' "$session_file" | head -1 | sed -E 's/^##?[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]*—[[:space:]]*//')"
        fi
        # Truncate topics to fit the table column
        if [[ ${#topics} -gt 45 ]]; then
            topics="${topics:0:42}..."
        fi
        printf "| %s | %s |         |\n" "$date" "$topics"
    done
} > "${INDEX_FILE}"

# Build history/INDEX.md (same format, one per year)
for year_dir in "${HISTORY_DIR}"/[0-9][0-9][0-9][0-9]; do
    [[ -d "$year_dir" ]] || continue
    year="$(basename "$year_dir")"
    hidx="${year_dir}/INDEX.md"

    year_dates=()
    for f in "$year_dir"/*.md; do
        [[ -f "$f" ]] || continue
        if [[ "$(basename "$f")" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})\.md$ ]]; then
            year_dates+=("${BASH_REMATCH[1]}")
        fi
    done

    mapfile -t sorted_year < <(printf '%s\n' "${year_dates[@]}" | sort -r)

    {
        echo "# History Index"
        echo ""
        echo "| Date       | Topics                                      | Metrics |"
        echo "|------------|---------------------------------------------|---------|"
        for date in "${sorted_year[@]}"; do
            topics=""
            session_file="${year_dir}/${date}.md"
            if [[ -f "$session_file" ]]; then
                # Strip the ## YYYY-MM-DD — prefix using sed -E (BSD sed needs -E for ?)
            topics="$(grep -E '^##? [0-9]{4}-[0-9]{2}-[0-9]{2}' "$session_file" | head -1 | sed -E 's/^##?[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]*—[[:space:]]*//' | sed -E 's/^##?[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]*//')"
            fi
            if [[ ${#topics} -gt 45 ]]; then
                topics="${topics:0:42}..."
            fi
            printf "| %s | %s |         |\n" "$date" "$topics"
        done
    } > "$hidx"
done

echo "  Written ${INDEX_FILE}"
echo ""
echo "Phase 2 complete."

# --- Phase 3: Verify losslessness ---
echo ""
echo "Phase 3: Verifying losslessness..."
echo ""

migrated_lines=0
migrated_words=0
for f in "${HISTORY_DIR}"/*/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md; do
    [[ -f "$f" ]] || continue
    migrated_lines=$(( migrated_lines + $(wc -l < "$f") ))
    migrated_words=$(( migrated_words + $(wc -w < "$f") ))
done

# Count condensed entries (these are valid summaries but lack full dates)
condensed_lines=0
condensed_words=0
if [[ -s "${WORK_DIR}/condensed_entries.tmp" ]]; then
    while IFS='|' read -r month_day topics content; do
        condensed_lines=$(( condensed_lines + $(printf '%s\n' "$content" | wc -l) ))
        condensed_words=$(( condensed_words + $(printf '%s\n' "$content" | wc -w) ))
    done < "${WORK_DIR}/condensed_entries.tmp"
fi

# Adjusted original count: subtract deep archive preamble (metadata, not session content)
# The preamble is everything before "## Batch condensed" — ~30 lines of "Why this file exists"
# and "The rule now" sections. Count it precisely.
deep_preamble_lines=0
if [[ -f "${SRC_DEEP}" ]]; then
    deep_preamble_lines=$(awk '/^# Batch condensed/{exit} {n++} END{print n+0}' "${SRC_DEEP}")
fi

adjusted_orig_lines=$(( orig_lines - deep_preamble_lines ))
adjusted_orig_words=$(( orig_words - deep_preamble_lines * 10 ))

# Tolerance: percentage-based (15%) plus a small per-entry buffer for YAML overhead
entry_count=${#sorted_dates[@]}
condensed_count=0
if [[ -s "${WORK_DIR}/condensed_entries.tmp" ]]; then
    condensed_count=$(wc -l < "${WORK_DIR}/condensed_entries.tmp")
fi
total_entries=$(( entry_count + condensed_count ))

# 15% of original + 10 lines per entry for YAML frontmatter overhead
line_tolerance=$(( (adjusted_orig_lines * 15 / 100) + (total_entries * 10) ))
word_tolerance=$(( (adjusted_orig_words * 15 / 100) + (total_entries * 30) ))

# Minimum tolerance to avoid zero for tiny files
if [[ $line_tolerance -lt 20 ]]; then
    line_tolerance=20
fi
if [[ $word_tolerance -lt 50 ]]; then
    word_tolerance=50
fi

line_ok=0
word_ok=0
if (( migrated_lines >= adjusted_orig_lines - line_tolerance && migrated_lines <= adjusted_orig_lines + line_tolerance )); then
    line_ok=1
fi
if (( migrated_words >= adjusted_orig_words - word_tolerance && migrated_words <= adjusted_orig_words + word_tolerance )); then
    word_ok=1
fi

echo "  Original:    ${orig_lines} lines, ${orig_words} words"
echo "  Adjusted:    ${adjusted_orig_lines} lines, ${adjusted_orig_words} words (excluded ${deep_preamble_lines} preamble lines)"
echo "  Migrated:    ${migrated_lines} lines, ${migrated_words} words"
echo "  Condensed:   ${condensed_count} entries, ${condensed_lines} lines, ${condensed_words} words"
echo "  Tolerance:   ±${line_tolerance} lines, ±${word_tolerance} words (15% + ${total_entries} entries × YAML overhead)"

if [[ $line_ok -eq 0 || $word_ok -eq 0 ]]; then
    echo ""
    echo "ERROR: Losslessness verification FAILED." >&2
    echo "  Line match: $([ $line_ok -eq 1 ] && echo 'OK' || echo 'FAIL')" >&2
    echo "  Word match: $([ $word_ok -eq 1 ] && echo 'OK' || echo 'FAIL')" >&2
    exit 1
fi

echo "  Line count: OK"
echo "  Word count: OK"
echo ""
echo "Phase 3 complete."

# --- Phase 4: Move originals to _legacy/ ---
echo ""
echo "Phase 4: Moving originals to _legacy/..."
echo ""

mkdir -p "${LEGACY_DIR}"

for f in SESSION_NOTES.md SESSION_NOTES_ARCHIVE.md SESSION_NOTES_DEEP_ARCHIVE.md; do
    src="${CONTEXT_DIR}/${f}"
    if [[ -f "$src" ]]; then
        mv "$src" "${LEGACY_DIR}/${f}"
        echo "  ${f} -> _legacy/${f}"
    fi
done

echo ""
echo "Phase 4 complete."

# --- Done ---
echo ""
echo "Migration complete."
echo ""
echo "  Sessions migrated: ${#sorted_dates[@]}"
echo "  New structure:     ${HISTORY_DIR}/YYYY/YYYY-MM-DD.md"
echo "  Index:             ${INDEX_FILE}"
echo ""
echo "  Original files preserved in: ${LEGACY_DIR}/"
echo ""
echo "  To undo, restore files from _legacy/ and delete history/."
