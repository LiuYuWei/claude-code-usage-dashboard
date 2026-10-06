# Claude Code Usage Dashboard

**English** · [繁體中文](README.zh-TW.md)

See how you use Claude Code — tokens, cost, models, tools, projects and when you work — on a dashboard that runs on your own machine. It reads the session logs Claude Code already keeps on your computer. **Nothing is uploaded anywhere**, and nothing you said to Claude is copied: only numbers and names.

Built on [open-dashboard](https://github.com/simonliu-ai-product/open-dashboard).

## What you see

| Panel | What it answers |
| --- | --- |
| Sessions, messages, API requests, output tokens, cost, lines added | The totals for the period and project you pick |
| Daily API requests (calendar) | Which days you used Claude Code, and how much |
| Weekly rhythm (hour × weekday) | When in the week you work with it |
| Daily output tokens by model | How your output splits across models, and when you switched |
| Cost by project | Where the money went |
| Prompt cache hit rate | How much of the input was served from the prompt cache |
| Most used tools · Tool failure rate | What Claude does for you, and what fails most |
| API time vs cost | Each session: time spent waiting on the API, its cost, lines it added |
| Recent sessions · Model share | The latest sessions, and which models answered |

Filter everything by period and by project.

## Your data stays on your machine

**What is read:** the session logs Claude Code writes to `~/.claude/projects/**/*.jsonl` (or `$CLAUDE_CONFIG_DIR/projects`).

**What is kept** — in `data/usage.db`, a SQLite file inside this folder:

- when each request and tool call happened, and in which project (the name of its git repository folder)
- the model, and the token counts (input, output, cache reads and writes)
- the name of each tool called, and whether it failed
- per session, the cost and lines added / removed that Claude Code itself recorded
- how many messages you typed — not what they said

**What is never kept:** your prompts, Claude's answers and thinking, session titles, file paths, file contents, commands, and tool inputs or outputs.

- `data/` is in `.gitignore`: your usage is never committed, so you can fork and push this project freely.
- The dashboard runs on `localhost` and only reads `data/usage.db` — read-only. It sends nothing to the internet.
- To remove everything it collected, delete `data/usage.db`.

## Get started

You need:

- [Node.js](https://nodejs.org) 22.18 or later, and [pnpm](https://pnpm.io)
- [uv](https://docs.astral.sh/uv/) for the collector (it installs the Python it needs on its own)
- Claude Code, used at least once on this computer

(With [mise](https://mise.jdx.dev), `mise install` sets up Node, pnpm and Python from `.mise.toml`.)

```bash
git clone https://github.com/LiuYuWei/claude-code-usage-dashboard.git
cd claude-code-usage-dashboard
pnpm install
pnpm dev
```

`pnpm dev` first collects your usage (a few seconds, even for hundreds of MB of logs), then opens the dashboard at **http://localhost:5473**.

## Keep it up to date

The collector reads only the logs that changed since last time. To bring the numbers up to date while the dashboard is open:

```bash
pnpm collect
```

then reload the page. Restarting `pnpm dev` does the same.

If Claude Code keeps its data somewhere else, point the collector at it:

```bash
CLAUDE_CONFIG_DIR=/path/to/claude-config pnpm collect
```

## Good to know

- **Cost is Claude Code's own figure**, written when a session ends. A session that is still open shows `—` until then, so the total is what finished sessions cost.
- **Projects are named after their git repository** — a session in `my-app/packages/web` counts for `my-app`. Outside a repository, it is the folder's own name.
- **Times are your computer's local time.**
- **Sessions can span days** when you resume them, so the dashboard uses the time spent waiting on the API, not first-to-last message, for how long a session took.
- The log format is Claude Code's own and may change between versions. If a panel goes empty after an update, please open an issue.

## Share a snapshot

The download button at the top right, beside Preview / Edit, saves the whole dashboard as a PNG or SVG — only the charts and totals, not the data behind them. Check what it shows first: **project names appear on it**, and they may be client or product names.

## Make it yours

This is an [open-dashboard](https://github.com/simonliu-ai-product/open-dashboard) workspace: the panels are React in `dashboards/usage/index.tsx`, the queries SQL in `dashboards/usage/queries.sql`, and what every table means is in `databases/usage/database.md`. The project ships with skills for coding agents — open it in Claude Code and ask for the panel you want ("add the cost per model by week").

```
collector/collect.py          reads ~/.claude/projects, writes data/usage.db
dashboards/usage/             the dashboard: index.tsx (layout) and queries.sql
databases/usage/database.md   every table and column
open-dashboard.config.ts      the data source: data/usage.db
```

```bash
pnpm collect                              # update data/usage.db
pnpm exec open-dashboard check            # run every query, verify every panel
pnpm exec open-dashboard query "SELECT model, COUNT(*) FROM requests GROUP BY model"
```

## License

MIT
