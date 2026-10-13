#!/usr/bin/env python3
"""hindsight-retain.py -- Retain documents into the Hindsight `health` bank.

Why this exists
  The Hindsight server speaks MCP over HTTP at <base>/mcp/<bank>/ and does NOT expose a
  REST "create document" route: POST /v1/<bank>/documents 404s, and the REST API only
  ingests via POST /v1/default/banks/<bank>/files/retain (multipart) or /import (bank
  template). Retention therefore goes through the MCP `retain` tool, using the required
  handshake (initialize -> notifications/initialized) and parsing the server's
  Server-Sent-Events responses. This is the same tool the agent uses in-session, so the
  headless path and the interactive path share one pipeline.

Idempotency
  The MCP `retain` tool is asynchronous and is not synchronously dedup-safe (repeating a
  retain with the same document_id returns a fresh operation_id). This helper therefore
  keeps a local manifest of document ids it has already retained and skips them on a
  re-run. Seed the manifest from the current bank first (--seed) so a backfill does not
  re-add documents that are already present.

Stdlib only. No third-party dependency.

Usage
  hindsight-retain.py --content "text" --id doc-id [--date YYYY-MM-DD] [--tag a,b]
  cat docs.ndjson | hindsight-retain.py --stdin      # one JSON object per line
  hindsight-retain.py --seed                          # populate the manifest from the bank
  hindsight-retain.py --dry-run --stdin               # show what would be retained, send nothing

Environment
  HINDSIGHT_API_KEY   Bearer token; falls back to ~/.hindsight/api_key
  HINDSIGHT_MCP_URL   e.g. http://192.168.1.63:8888/mcp/health/  (default; --host derives it)
  HINDSIGHT_BASE      base URL used with --host, default http://192.168.1.63:8888
  HINDSIGHT_BANK      bank name, default "health"
  HINDSIGHT_MANIFEST  path to the id manifest, default ~/.hindsight/retain-manifest.json

Exit codes
  0  every document retained, or a dry-run / seed
  1  at least one retain failed (details on stderr)
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request

DEFAULT_BASE = "http://192.168.1.63:8888"
DEFAULT_BANK = "health"
PROTOCOL_VERSION = "2024-11-05"


def load_api_key():
    key = os.environ.get("HINDSIGHT_API_KEY", "").strip()
    if not key:
        path = os.path.expanduser("~/.hindsight/api_key")
        if os.path.exists(path):
            with open(path, encoding="utf-8") as fh:
                key = fh.read().strip()
    return key


def build_mcp_url(host=None):
    if host:
        base = os.environ.get("HINDSIGHT_BASE", DEFAULT_BASE).rstrip("/")
        bank = os.environ.get("HINDSIGHT_BANK", DEFAULT_BANK)
        return f"{base}/mcp/{bank}/"
    return os.environ.get("HINDSIGHT_MCP_URL", f"{DEFAULT_BASE}/mcp/{DEFAULT_BANK}/")


def manifest_path():
    return os.environ.get("HINDSIGHT_MANIFEST", os.path.expanduser("~/.hindsight/retain-manifest.json"))


def load_manifest():
    path = manifest_path()
    if not os.path.exists(path):
        return set()
    try:
        with open(path, encoding="utf-8") as fh:
            return set(json.load(fh))
    except (ValueError, OSError):
        print(f"warning: manifest {path} unreadable, starting fresh", file=sys.stderr)
        return set()


def save_manifest(ids):
    path = manifest_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(sorted(ids), fh, indent=2)
    os.replace(tmp, path)


def post(url, payload, api_key, session_id=None, timeout=60):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Authorization", "Bearer " + api_key)
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json, text/event-stream")
    if session_id:
        req.add_header("Mcp-Session-Id", session_id)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, dict(resp.headers), resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        return exc.code, dict(exc.headers or {}), exc.read().decode("utf-8", "replace")
    except Exception as exc:  # network error, timeout, etc.
        return 0, {}, f"{type(exc).__name__}: {exc}"


def get_json(url, api_key, timeout=30):
    req = urllib.request.Request(url)
    req.add_header("Authorization", "Bearer " + api_key)
    req.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", "replace")
    except Exception as exc:
        return 0, f"{type(exc).__name__}: {exc}"


def parse_sse(raw):
    """MCP Streamable HTTP wraps results in SSE frames: 'event: message\\ndata: {...}'.
    Concatenate the data: payloads; fall back to the raw body if none are framed."""
    frames = [line[5:].strip() for line in raw.splitlines() if line.startswith("data:")]
    return "\n".join(frames) if frames else raw.strip()


def open_session(mcp_url, api_key):
    init = {
        "jsonrpc": "2.0", "id": 0, "method": "initialize",
        "params": {"protocolVersion": PROTOCOL_VERSION, "capabilities": {},
                   "clientInfo": {"name": "hindsight-retain", "version": "1.0"}},
    }
    status, headers, body = post(mcp_url, init, api_key)
    if status != 200:
        raise RuntimeError(f"initialize failed: HTTP {status} {body[:200]}")
    session_id = headers.get("Mcp-Session-Id") or headers.get("mcp-session-id")
    if not session_id:
        raise RuntimeError(f"initialize returned no Mcp-Session-Id: {body[:200]}")
    post(mcp_url, {"jsonrpc": "2.0", "method": "notifications/initialized"},
         api_key, session_id=session_id)
    return session_id


def retain_one(mcp_url, api_key, session_id, doc):
    args = {"content": doc["content"]}
    if doc.get("id"):
        args["document_id"] = doc["id"]
    if doc.get("date"):
        args["timestamp"] = doc["date"]
    if doc.get("tags"):
        args["tags"] = doc["tags"]
    if doc.get("context"):
        args["context"] = doc["context"]
    call = {"jsonrpc": "2.0", "id": 1, "method": "tools/call",
            "params": {"name": "retain", "arguments": args}}
    status, _, body = post(mcp_url, call, api_key, session_id=session_id)
    label = doc.get("id") or "(no id)"
    if status != 200:
        print(f"  FAIL {label}: HTTP {status} {body[:160]}", file=sys.stderr)
        return False
    payload = parse_sse(body)
    try:
        obj = json.loads(payload)
    except ValueError:
        print(f"  FAIL {label}: unparseable response {payload[:160]}", file=sys.stderr)
        return False
    if "error" in obj:
        print(f"  FAIL {label}: {obj['error']}", file=sys.stderr)
        return False
    print(f"  OK   {label}")
    return True


def seed_manifest(mcp_url, api_key, base, bank, manifest):
    """Record every document id currently in the bank so a backfill skips them."""
    status, body = get_json(f"{base}/v1/default/banks/{bank}/documents?limit=1000", api_key)
    if status != 200:
        print(f"warning: could not list bank documents (HTTP {status}); "
              f"backfill may re-add existing docs", file=sys.stderr)
        return 0
    try:
        data = json.loads(body)
    except ValueError:
        print(f"warning: bank document list was not JSON: {body[:120]}", file=sys.stderr)
        return 0
    rows = data if isinstance(data, list) else (data.get("documents") or data.get("items") or [])
    seeded = 0
    for row in rows:
        doc_id = row.get("id") or row.get("document_id") if isinstance(row, dict) else None
        if doc_id:
            manifest.add(doc_id)
            seeded += 1
    save_manifest(manifest)
    print(f"  seeded {seeded} existing document id(s) from the bank into the manifest")
    return seeded


def load_docs(args):
    if args.stdin:
        docs = []
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                docs.append(json.loads(line))
            except ValueError:
                print(f"warning: skipping malformed NDJSON line: {line[:80]}", file=sys.stderr)
        return docs
    return [{"id": args.id, "content": args.content, "date": args.date,
             "tags": args.tag, "context": args.context}]


def main():
    p = argparse.ArgumentParser(description="Retain documents into the Hindsight health bank (MCP).")
    p.add_argument("--content", help="document content (single-doc mode)")
    p.add_argument("--id", dest="id", help="document id (single-doc mode)")
    p.add_argument("--date", help="document date YYYY-MM-DD (single-doc mode)")
    p.add_argument("--tag", action="append", default=[],
                   help="document tag (repeatable or comma list)")
    p.add_argument("--context", help="optional context for the retain")
    p.add_argument("--stdin", action="store_true",
                   help="read NDJSON documents from stdin (one JSON object per line)")
    p.add_argument("--seed", action="store_true",
                   help="populate the manifest from the current bank, then stop")
    p.add_argument("--dry-run", action="store_true", help="show what would be retained, send nothing")
    p.add_argument("--host", help="Hindsight host (e.g. 192.168.1.63); derives the MCP URL")
    args = p.parse_args()

    tags = []
    for t in args.tag:
        tags.extend(x for x in t.split(",") if x)
    args.tag = tags

    mcp_url = build_mcp_url(args.host)
    base = (mcp_url.rsplit("/mcp/", 1)[0]).rstrip("/")
    bank = os.environ.get("HINDSIGHT_BANK", DEFAULT_BANK)

    api_key = load_api_key()
    if not api_key:
        print("error: HINDSIGHT_API_KEY not set and ~/.hindsight/api_key not found", file=sys.stderr)
        return 1

    manifest = load_manifest()

    if args.seed:
        print(f"=== Seeding manifest from {base}/v1/default/banks/{bank} ===")
        seed_manifest(mcp_url, api_key, base, bank, manifest)
        return 0

    docs = load_docs(args)
    if not docs:
        print("nothing to retain", file=sys.stderr)
        return 0

    to_send = [d for d in docs if not (d.get("id") and d["id"] in manifest)]
    skipped = len(docs) - len(to_send)
    print(f"=== {len(docs)} document(s); {skipped} already in manifest, {len(to_send)} to retain ===")
    if args.dry_run:
        for d in to_send:
            print(f"  [DRY RUN] {d.get('id') or '(no id)'} "
                  f"({len(d.get('content', ''))} chars, date {d.get('date', '?')})")
        return 0

    try:
        session_id = open_session(mcp_url, api_key)
    except RuntimeError as exc:
        print(f"error: could not open MCP session at {mcp_url}: {exc}", file=sys.stderr)
        return 1

    failures = 0
    for doc in to_send:
        if not retain_one(mcp_url, api_key, session_id, doc):
            failures += 1
        else:
            if doc.get("id"):
                manifest.add(doc["id"])
    save_manifest(manifest)

    print(f"=== Done: {len(to_send) - failures} retained, {failures} failed ===")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
