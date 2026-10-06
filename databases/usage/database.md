# usage

Claude Code usage on this machine, collected by `collector/collect.py` (`pnpm collect`, and before every `pnpm dev`) from the session transcripts in `~/.claude/projects/**/*.jsonl` (or `$CLAUDE_CONFIG_DIR/projects`). **Numbers and names only**: no prompts, answers, thinking, session titles, file paths or commands are copied. The database stays in `data/` and is git-ignored.

## Notes

- Timestamps are ISO 8601 in **UTC** (`2026-01-31T09:30:00.000Z`): use `date(ts, 'localtime')` / `strftime(…, ts, 'localtime')` for days and hours.
- `project` is the folder name of the git repository the session ran in (`my-app` for a session in `my-app/packages/web`), or of the directory itself outside a repository (`notes` for `~/notes`).
- One response is written as several transcript lines; `requests` holds it once, keyed by the API message id.
- `model = '<synthetic>'` marks messages Claude Code wrote itself (no API call): leave them out of request counts.
- Cost and lines changed are **Claude Code's own record** (`cost-state`), per session — not computed here. A session without one has no row in `session_costs`.
- A session can be resumed over several days, so `ended − started` is not working time; `session_costs.api_seconds` is the time spent waiting on the API.
- Input tokens come in three kinds: `input_tokens` (not cached), `cache_write_tokens` (written to the prompt cache) and `cache_read_tokens` (served from it).

## Tables

### sessions
`session_id`, `project`, `started`, `ended` (first and last transcript line), `version` (Claude Code), `entrypoint` (cli, desktop …).

### requests
One row per API response: `ts`, `session_id`, `project`, `model`, `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_write_tokens`, `subagent` (1 when a subagent made it), `stop_reason`.

### tool_calls
One row per tool call: `ts`, `session_id`, `project`, `tool` (MCP tools as `mcp__<server>__<tool>`), `subagent`, `is_error` (1 when the result was an error — including a question the user declined).

### prompts
One row per message the person typed (not tool results, not meta lines, not subagents): `uuid`, `ts`, `session_id`, `project`.

### session_costs
Per session, Claude Code's last recorded totals: `cost_usd`, `lines_added`, `lines_removed`, `api_seconds`, `total_seconds`.

### files
The collector's bookkeeping: each transcript's size and mtime when it was last read.
