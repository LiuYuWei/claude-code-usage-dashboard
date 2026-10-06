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

A second dashboard, **Claude Code insights**, digs deeper:

| Panel | What it answers |
| --- | --- |
| Tool flow (Sankey) | What Claude does next after reading, editing, running a command, using the browser… |
| Cost concentration (Pareto) | How much of the spend the costliest 20 % of sessions account for |
| Weekly project rank · Weekly requests per project | Which project was the main one each week |
| Output tokens per response by model (box plot) | How long each model's answers run |
| Cumulative session cost (ECDF) | "Half of my sessions cost under X, 90 % under Y" |
| Daily requests with control limits | Days far above your usual use |
| Tool mix per project (Marimekko) | Whether a project is mostly commands, edits, reading or browsing |
| Net lines per project · Requests per message | Which projects grew, and how far Claude goes on its own per message |
| Return to new projects (cohort) | How often you come back to a project in the weeks after starting it |

## Why does my usage run out so fast?

The third dashboard, **Claude Code usage diagnosis**, is for this question. Most of what a request costs is usually not the answer Claude writes but the conversation it has to **read again** before answering — on long sessions, well over 99 % of the tokens. What drives it, and where to see it:

| On the dashboard | What it means | What helps |
| --- | --- | --- |
| **Share of tokens spent reading** close to 100 %, **context per request** in the hundreds of thousands | Every message re-reads the whole conversation so far | Start a new conversation for a new task (`/clear`), or `/compact` a long one |
| **Context growth** climbing in a sawtooth up to the model's limit | The conversation is never cleared; it only shrinks when it is compacted automatically, then grows again | Same: clear between tasks instead of carrying one session all day |
| **Characters tool results put into the context** led by one tool | Long command output, large files or many screenshots stay in the context and are read again on every later request | Ask for shorter output (`… \| tail -50`), read parts of large files, take fewer screenshots |
| **Cache rebuilds** | After a pause the prompt cache has expired, and the whole context is written to it again | Long pauses in a huge session cost more; start fresh after a break |
| **Subagent requests** | Each subagent works with its own context, in parallel | Use subagents for work that needs them |
| **Tokens by model** | Larger models use more of a plan's allowance for the same work | Use a smaller model for routine work |
| **Tokens per five-hour window** | Plan usage is counted per window; this shows which windows were heavy | Spread heavy work, or keep the context small in the busy ones |

The five-hour windows are reconstructed from the logs (a window opens with the first request after the previous one closed); they are an approximation, not your plan's own meter.

## Your data stays on your machine

**What is read:** the session logs Claude Code writes to `~/.claude/projects/**/*.jsonl` (or `$CLAUDE_CONFIG_DIR/projects`).

**What is kept** — in `data/usage.db`, a SQLite file inside this folder:

- when each request and tool call happened, and in which project (the name of its git repository folder)
- the model, and the token counts (input, output, cache reads and writes)
- the name of each tool called, whether it failed, and how large its result was (characters and images — not the result itself)
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
dashboards/usage/             the overview: index.tsx (layout) and queries.sql
dashboards/insights/          the deeper analysis, same layout
dashboards/diagnosis/         why usage runs out, same layout
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
