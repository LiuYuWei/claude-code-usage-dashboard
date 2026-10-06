-- name: tool_flow
-- description: What Claude does next: each tool call (by kind) and the kind of the call that follows it in the same session. Left is the call, right the next one.
WITH c AS (
  SELECT session_id, ts, tool_use_id, CASE
           WHEN tool IN ('Bash', 'Monitor') THEN '指令'
           WHEN tool IN ('Read', 'Grep', 'Glob', 'LS') THEN '讀取'
           WHEN tool IN ('Write', 'Edit', 'MultiEdit', 'NotebookEdit') THEN '編輯'
           WHEN tool LIKE 'mcp__claude-in-chrome__%' THEN '瀏覽器'
           WHEN tool IN ('WebFetch', 'WebSearch') THEN '網路搜尋'
           WHEN tool IN ('AskUserQuestion', 'SendUserFile', 'EnterPlanMode', 'ExitPlanMode') THEN '與你互動'
           WHEN tool IN ('Agent', 'Task', 'TaskCreate', 'TaskUpdate', 'TaskStop', 'SubagentHandback') THEN '子 Agent 與任務'
           WHEN tool LIKE 'mcp__%' THEN '其他 MCP'
           ELSE '其他'
         END AS kind
  FROM tool_calls WHERE subagent = 0 AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
), n AS (
  SELECT kind, LEAD(kind) OVER (PARTITION BY session_id ORDER BY ts, tool_use_id) AS next FROM c
)
SELECT kind AS source, '→ ' || next AS target, COUNT(*) AS calls
FROM n WHERE next IS NOT NULL GROUP BY kind, next HAVING calls >= 5;

-- name: cost_pareto
-- description: Every session's cost (Claude Code's own record), for how concentrated spending is
SELECT substr(c.session_id, 1, 8) AS session, c.cost_usd AS cost
FROM session_costs c JOIN sessions s USING (session_id)
WHERE c.cost_usd > 0 AND date(s.started, 'localtime') >= :from AND date(s.started, 'localtime') < :to;

-- name: weekly_rank
-- description: API requests per week for the five projects with the most requests in the range, ranked within each week (weeks start on Monday)
WITH top AS (
  SELECT project FROM requests WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
  GROUP BY project ORDER BY COUNT(*) DESC LIMIT 5
)
SELECT date(ts, 'localtime', 'weekday 1', '-7 days') AS week, project, COUNT(*) AS requests
FROM requests WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
  AND project IN (SELECT project FROM top)
GROUP BY week, project ORDER BY week;

-- name: weekly_top
-- description: API requests per week for the six projects with the most requests
WITH top AS (
  SELECT project FROM requests WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
  GROUP BY project ORDER BY COUNT(*) DESC LIMIT 6
)
SELECT date(ts, 'localtime', 'weekday 1', '-7 days') AS week, project, COUNT(*) AS requests
FROM requests WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to AND project IN (SELECT project FROM top)
GROUP BY week, project ORDER BY week;

-- name: output_by_model
-- description: Output tokens per response by model: the box spans the quartiles, the whiskers the 5th to 95th percentile (the longest answers run past it)
WITH r AS (
  SELECT model, output_tokens,
         ROW_NUMBER() OVER (PARTITION BY model ORDER BY output_tokens) AS i,
         COUNT(*) OVER (PARTITION BY model) AS n
  FROM requests WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
)
SELECT model,
       MAX(CASE WHEN i = CAST(n * 0.05 AS INTEGER) + 1 THEN output_tokens END) AS p5,
       MAX(CASE WHEN i = CAST(n * 0.25 AS INTEGER) + 1 THEN output_tokens END) AS p25,
       MAX(CASE WHEN i = CAST(n * 0.5 AS INTEGER) + 1 THEN output_tokens END) AS p50,
       MAX(CASE WHEN i = CAST(n * 0.75 AS INTEGER) + 1 THEN output_tokens END) AS p75,
       MAX(CASE WHEN i = CAST(n * 0.95 AS INTEGER) + 1 THEN output_tokens END) AS p95
FROM r GROUP BY model HAVING COUNT(*) >= 20;

-- name: session_costs
-- description: Each session's cost, for its distribution
SELECT c.cost_usd AS cost
FROM session_costs c JOIN sessions s USING (session_id)
WHERE c.cost_usd > 0 AND date(s.started, 'localtime') >= :from AND date(s.started, 'localtime') < :to;

-- name: daily_requests
-- description: API requests per day; the limits are the mean ± 3 standard deviations of the days shown
SELECT date(ts, 'localtime') AS day, COUNT(*) AS requests
FROM requests WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
GROUP BY day ORDER BY day;

-- name: project_tools
-- description: Tool calls per project and kind of tool, for the ten projects with the most calls
WITH c AS (SELECT project, CASE
           WHEN tool IN ('Bash', 'Monitor') THEN '指令'
           WHEN tool IN ('Read', 'Grep', 'Glob', 'LS') THEN '讀取'
           WHEN tool IN ('Write', 'Edit', 'MultiEdit', 'NotebookEdit') THEN '編輯'
           WHEN tool LIKE 'mcp__claude-in-chrome__%' THEN '瀏覽器'
           WHEN tool IN ('WebFetch', 'WebSearch') THEN '網路搜尋'
           WHEN tool IN ('AskUserQuestion', 'SendUserFile', 'EnterPlanMode', 'ExitPlanMode') THEN '與你互動'
           WHEN tool IN ('Agent', 'Task', 'TaskCreate', 'TaskUpdate', 'TaskStop', 'SubagentHandback') THEN '子 Agent 與任務'
           WHEN tool LIKE 'mcp__%' THEN '其他 MCP'
           ELSE '其他'
         END AS kind FROM tool_calls WHERE date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to),
top AS (SELECT project FROM c GROUP BY project ORDER BY COUNT(*) DESC LIMIT 10)
SELECT project, kind, COUNT(*) AS calls FROM c WHERE project IN (SELECT project FROM top)
GROUP BY project, kind ORDER BY project;

-- name: net_lines
-- description: Lines added minus lines removed per project (Claude Code's own record), the eight largest changes
SELECT s.project, SUM(COALESCE(c.lines_added, 0) - COALESCE(c.lines_removed, 0)) AS net
FROM session_costs c JOIN sessions s USING (session_id)
WHERE date(s.started, 'localtime') >= :from AND date(s.started, 'localtime') < :to
GROUP BY s.project HAVING net <> 0 ORDER BY ABS(net) DESC LIMIT 8;

-- name: autonomy
-- description: API requests per message typed, per project with at least ten messages: how far Claude goes on its own per message
WITH p AS (SELECT project, COUNT(*) AS prompts FROM prompts WHERE date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to GROUP BY project),
r AS (SELECT project, COUNT(*) AS requests FROM requests WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to GROUP BY project)
SELECT p.project, CAST(r.requests AS REAL) / p.prompts AS per_message
FROM p JOIN r USING (project) WHERE p.prompts >= 10 ORDER BY per_message DESC LIMIT 12;

-- name: project_return
-- description: Projects by the week they were first used, and how many were used again in each week after
WITH active AS (
  SELECT DISTINCT project, date(ts, 'localtime', 'weekday 1', '-7 days') AS week FROM requests WHERE model <> '<synthetic>'
), first AS (
  SELECT project, MIN(week) AS cohort FROM active GROUP BY project
), sized AS (
  SELECT cohort, COUNT(*) AS size FROM first GROUP BY cohort
)
SELECT f.cohort, CAST((julianday(a.week) - julianday(f.cohort)) / 7 AS INTEGER) AS week_number,
       COUNT(*) AS projects, s.size
FROM first f JOIN active a USING (project) JOIN sized s USING (cohort)
WHERE f.cohort >= :from
GROUP BY f.cohort, week_number ORDER BY f.cohort, week_number;
