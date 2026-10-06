-- name: projects
-- description: Every project with a session, most requests first
SELECT project FROM requests GROUP BY project ORDER BY COUNT(*) DESC;

-- name: totals
-- description: Headline figures in the range and project. Cost and lines changed are Claude Code's own per-session record (cost-state), counted by the day the session started.
SELECT
  (SELECT COUNT(*) FROM sessions WHERE date(started, 'localtime') >= :from AND date(started, 'localtime') < :to AND (COALESCE(:project, '') = '' OR project = :project)) AS sessions,
  (SELECT COUNT(*) FROM prompts WHERE date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to AND (COALESCE(:project, '') = '' OR project = :project)) AS prompts,
  (SELECT COUNT(*) FROM requests WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to AND (COALESCE(:project, '') = '' OR project = :project)) AS requests,
  (SELECT SUM(output_tokens) FROM requests WHERE date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to AND (COALESCE(:project, '') = '' OR project = :project)) AS output_tokens,
  (SELECT SUM(c.cost_usd) FROM session_costs c JOIN sessions s USING (session_id) WHERE date(s.started, 'localtime') >= :from AND date(s.started, 'localtime') < :to AND (COALESCE(:project, '') = '' OR s.project = :project)) AS cost,
  (SELECT SUM(c.lines_added) FROM session_costs c JOIN sessions s USING (session_id) WHERE date(s.started, 'localtime') >= :from AND date(s.started, 'localtime') < :to AND (COALESCE(:project, '') = '' OR s.project = :project)) AS lines_added;

-- name: daily
-- description: API requests per day (local time)
SELECT date(ts, 'localtime') AS day, COUNT(*) AS requests
FROM requests
WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
  AND (COALESCE(:project, '') = '' OR project = :project)
GROUP BY day ORDER BY day;

-- name: rhythm
-- description: API requests by weekday and hour of the day (local time)
WITH r AS (
  SELECT CAST(strftime('%w', ts, 'localtime') AS INTEGER) AS dow, CAST(strftime('%H', ts, 'localtime') AS INTEGER) AS hour
  FROM requests
  WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
    AND (COALESCE(:project, '') = '' OR project = :project)
)
SELECT printf('%02d', hour) AS hour,
       CASE dow WHEN 1 THEN '週一' WHEN 2 THEN '週二' WHEN 3 THEN '週三' WHEN 4 THEN '週四' WHEN 5 THEN '週五' WHEN 6 THEN '週六' ELSE '週日' END AS weekday,
       (dow + 6) % 7 AS weekday_order, COUNT(*) AS requests
FROM r GROUP BY hour, dow ORDER BY weekday_order, hour;

-- name: output_by_model
-- description: Output tokens per day and model
SELECT date(ts, 'localtime') AS day, model, SUM(output_tokens) AS tokens
FROM requests
WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
  AND (COALESCE(:project, '') = '' OR project = :project)
GROUP BY day, model ORDER BY day;

-- name: project_cost
-- description: Cost per project, from Claude Code's per-session record, by the day the session started
SELECT s.project, SUM(c.cost_usd) AS cost
FROM session_costs c JOIN sessions s USING (session_id)
WHERE date(s.started, 'localtime') >= :from AND date(s.started, 'localtime') < :to
  AND (COALESCE(:project, '') = '' OR s.project = :project)
GROUP BY s.project HAVING cost > 0 ORDER BY cost DESC;

-- name: cache_rate
-- description: The share of input tokens served from the prompt cache: cache reads ÷ (uncached input + cache writes + cache reads)
SELECT CAST(SUM(cache_read_tokens) AS REAL) / NULLIF(SUM(input_tokens + cache_write_tokens + cache_read_tokens), 0) AS rate
FROM requests
WHERE date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
  AND (COALESCE(:project, '') = '' OR project = :project);

-- name: tools
-- description: Tool calls by tool, the most used first (top 12)
SELECT replace(replace(tool, 'mcp__', ''), '__', ' · ') AS tool, COUNT(*) AS calls
FROM tool_calls
WHERE date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
  AND (COALESCE(:project, '') = '' OR project = :project)
GROUP BY tool ORDER BY calls DESC LIMIT 12;

-- name: tool_errors
-- description: The share of each tool's calls whose result was an error (tools called at least 20 times)
SELECT replace(replace(tool, 'mcp__', ''), '__', ' · ') AS tool, AVG(is_error) AS error_rate, COUNT(*) AS calls
FROM tool_calls
WHERE date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
  AND (COALESCE(:project, '') = '' OR project = :project)
GROUP BY tool HAVING calls >= 20 ORDER BY error_rate DESC LIMIT 10;

-- name: session_scatter
-- description: Each session's time spent waiting on the API in minutes (Claude Code's own record), its cost and the lines it added
SELECT s.project,
       c.api_seconds / 60 AS minutes,
       c.cost_usd AS cost,
       COALESCE(c.lines_added, 0) AS lines_added
FROM sessions s JOIN session_costs c USING (session_id)
WHERE date(s.started, 'localtime') >= :from AND date(s.started, 'localtime') < :to
  AND (COALESCE(:project, '') = '' OR s.project = :project)
  AND c.cost_usd > 0;

-- name: model_share
-- description: API requests by model
SELECT model, COUNT(*) AS requests
FROM requests
WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
  AND (COALESCE(:project, '') = '' OR project = :project)
GROUP BY model ORDER BY requests DESC;

-- name: recent_sessions
-- description: The latest sessions: when, where, how much was asked, what it cost and what it changed
SELECT strftime('%m/%d %H:%M', s.started, 'localtime') AS started, s.project,
       (SELECT COUNT(*) FROM prompts p WHERE p.session_id = s.session_id) AS prompts,
       (SELECT COUNT(*) FROM requests r WHERE r.session_id = s.session_id) AS requests,
       c.cost_usd AS cost, c.lines_added, c.lines_removed
FROM sessions s LEFT JOIN session_costs c USING (session_id)
WHERE date(s.started, 'localtime') >= :from AND date(s.started, 'localtime') < :to
  AND (COALESCE(:project, '') = '' OR s.project = :project)
ORDER BY s.started DESC LIMIT 40;
