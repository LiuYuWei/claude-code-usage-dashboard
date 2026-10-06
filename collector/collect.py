"""Collect Claude Code usage — numbers and names only — into ../data/usage.db.

Claude Code keeps every session as JSON Lines under ~/.claude/projects (or
$CLAUDE_CONFIG_DIR/projects when that is set). This
reads them and keeps only what a usage dashboard needs: when, which project,
which model, how many tokens, which tools (by name) and whether they failed,
and the cost and lines changed Claude Code itself recorded per session.

It never copies what was said: no prompts, answers, thinking, titles, file
paths or commands. A file is read again only when it has changed.

    pnpm collect
"""

import functools
import json
import os
import sqlite3
from pathlib import Path

SOURCE = Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude").expanduser() / "projects"
DB = Path(__file__).resolve().parent.parent / "data" / "usage.db"
HOME = str(Path.home())
NAMING = 3

SCHEMA = """
CREATE TABLE IF NOT EXISTS files (path TEXT PRIMARY KEY, size INTEGER, mtime REAL);
CREATE TABLE IF NOT EXISTS sessions (
  session_id TEXT PRIMARY KEY, file TEXT, project TEXT, started TEXT, ended TEXT,
  version TEXT, entrypoint TEXT);
CREATE TABLE IF NOT EXISTS requests (
  message_id TEXT PRIMARY KEY, file TEXT, session_id TEXT, project TEXT, ts TEXT, model TEXT,
  input_tokens INTEGER, output_tokens INTEGER, cache_read_tokens INTEGER, cache_write_tokens INTEGER,
  subagent INTEGER, stop_reason TEXT);
CREATE TABLE IF NOT EXISTS tool_calls (
  tool_use_id TEXT PRIMARY KEY, file TEXT, session_id TEXT, project TEXT, ts TEXT, tool TEXT,
  subagent INTEGER, is_error INTEGER, result_chars INTEGER, result_images INTEGER);
CREATE TABLE IF NOT EXISTS prompts (uuid TEXT PRIMARY KEY, file TEXT, session_id TEXT, project TEXT, ts TEXT);
CREATE TABLE IF NOT EXISTS session_costs (
  session_id TEXT PRIMARY KEY, file TEXT, cost_usd REAL, lines_added INTEGER, lines_removed INTEGER,
  api_seconds REAL, total_seconds REAL);
"""


@functools.cache
def project_of(cwd: str | None) -> str:
    """The project a working directory belongs to: the folder name of its git
    repository, or of the directory itself when it is not in one."""
    if not cwd:
        return "—"
    path = Path(cwd)
    for folder in (path, *path.parents):
        if str(folder) in (HOME, "/"):
            break
        if (folder / ".git").exists():
            return folder.name
    return path.name or cwd


def is_prompt(record: dict) -> bool:
    """A message the person typed: not a tool result, not a meta line, not a subagent's."""
    if record.get("isMeta") or record.get("isSidechain"):
        return False
    content = (record.get("message") or {}).get("content")
    if isinstance(content, str):
        return bool(content.strip())
    if isinstance(content, list):
        kinds = {part.get("type") for part in content if isinstance(part, dict)}
        return "text" in kinds and "tool_result" not in kinds
    return False


def result_size(content) -> tuple[int, int]:
    """A tool result's size: characters of text, and the number of images."""
    if isinstance(content, str):
        return len(content), 0
    chars = images = 0
    for part in content if isinstance(content, list) else []:
        if isinstance(part, dict) and part.get("type") == "image":
            images += 1
        elif isinstance(part, dict):
            chars += len(part.get("text") or "")
    return chars, images


def read_file(db: sqlite3.Connection, path: Path) -> None:
    file = str(path)
    for table in ("sessions", "requests", "tool_calls", "prompts", "session_costs"):
        db.execute(f"DELETE FROM {table} WHERE file = ?", (file,))

    sessions: dict[str, dict] = {}
    requests: dict[str, tuple] = {}
    calls: dict[str, list] = {}
    errors: set[str] = set()
    prompts: list[tuple] = []
    costs: dict[str, tuple] = {}

    for line in path.open(encoding="utf-8", errors="replace"):
        try:
            record = json.loads(line)
        except ValueError:
            continue
        kind = record.get("type")
        session = record.get("sessionId")
        ts = record.get("timestamp")
        project = project_of(record.get("cwd"))

        if session and ts:
            s = sessions.setdefault(session, {"project": project, "started": ts, "ended": ts})
            s["started"] = min(s["started"], ts)
            s["ended"] = max(s["ended"], ts)
            if record.get("cwd"):
                s["project"] = project
            s["version"] = record.get("version") or s.get("version")
            s["entrypoint"] = record.get("entrypoint") or s.get("entrypoint")

        if kind == "assistant":
            message = record.get("message") or {}
            usage = message.get("usage") or {}
            sub = int(bool(record.get("isSidechain")))
            # One response is written as several lines (one per content block)
            # carrying the same id and usage: count it once.
            if message.get("id") and usage:
                requests[message["id"]] = (
                    message["id"], file, session, project, ts, message.get("model"),
                    usage.get("input_tokens") or 0, usage.get("output_tokens") or 0,
                    usage.get("cache_read_input_tokens") or 0, usage.get("cache_creation_input_tokens") or 0,
                    sub, message.get("stop_reason"),
                )
            for part in message.get("content") or []:
                if isinstance(part, dict) and part.get("type") == "tool_use" and part.get("id"):
                    calls[part["id"]] = [part["id"], file, session, project, ts, part.get("name"), sub, 0, 0, 0]

        elif kind == "user":
            content = (record.get("message") or {}).get("content")
            if isinstance(content, list):
                for part in content:
                    if not (isinstance(part, dict) and part.get("type") == "tool_result"):
                        continue
                    if part.get("is_error"):
                        errors.add(part.get("tool_use_id"))
                    # How much the result put into the context — its size, never its text.
                    size = result_size(part.get("content"))
                    if part.get("tool_use_id") in calls:
                        calls[part["tool_use_id"]][8] += size[0]
                        calls[part["tool_use_id"]][9] += size[1]
            if is_prompt(record) and record.get("uuid"):
                prompts.append((record["uuid"], file, session, project, ts))

        elif kind == "cost-state" and session:
            costs[session] = (
                session, file, record.get("totalCostUSD"), record.get("totalLinesAdded"),
                record.get("totalLinesRemoved"),
                (record.get("totalAPIDuration") or 0) / 1000, (record.get("totalDuration") or 0) / 1000,
            )

    for call_id in errors & calls.keys():
        calls[call_id][7] = 1
    db.executemany(
        "INSERT OR REPLACE INTO sessions VALUES (?, ?, ?, ?, ?, ?, ?)",
        [(sid, file, s["project"], s["started"], s["ended"], s.get("version"), s.get("entrypoint")) for sid, s in sessions.items()],
    )
    db.executemany("INSERT OR REPLACE INTO requests VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", requests.values())
    db.executemany("INSERT OR REPLACE INTO tool_calls VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", calls.values())
    db.executemany("INSERT OR REPLACE INTO prompts VALUES (?, ?, ?, ?, ?)", prompts)
    db.executemany("INSERT OR REPLACE INTO session_costs VALUES (?, ?, ?, ?, ?, ?, ?)", costs.values())


def main() -> None:
    DB.parent.mkdir(exist_ok=True)
    db = sqlite3.connect(DB)
    db.executescript(SCHEMA)
    # A change to what is stored (a column, how projects are named) rebuilds it all.
    if db.execute("PRAGMA user_version").fetchone()[0] != NAMING:
        for table in ("files", "sessions", "requests", "tool_calls", "prompts", "session_costs"):
            db.execute(f"DROP TABLE IF EXISTS {table}")
        db.executescript(SCHEMA)
        db.execute(f"PRAGMA user_version = {NAMING}")
    seen = {path: (size, mtime) for path, size, mtime in db.execute("SELECT path, size, mtime FROM files")}
    if not SOURCE.is_dir():
        print(f"No Claude Code sessions found in {SOURCE} — use Claude Code once, or set CLAUDE_CONFIG_DIR.")
    changed = 0
    for path in sorted(SOURCE.glob("**/*.jsonl")):
        stat = path.stat()
        if seen.get(str(path)) == (stat.st_size, stat.st_mtime):
            continue
        read_file(db, path)
        db.execute("INSERT OR REPLACE INTO files VALUES (?, ?, ?)", (str(path), stat.st_size, stat.st_mtime))
        db.commit()
        changed += 1
    totals = db.execute(
        "SELECT (SELECT COUNT(*) FROM sessions), (SELECT COUNT(*) FROM requests), (SELECT COUNT(*) FROM tool_calls)"
    ).fetchone()
    print(f"read {changed} changed file(s); {totals[0]} sessions, {totals[1]} requests, {totals[2]} tool calls")
    db.close()


if __name__ == "__main__":
    main()
