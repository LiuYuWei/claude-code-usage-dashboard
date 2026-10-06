-- name: diagnosis_totals
-- description: Per API request in the range: the context it read (uncached input + cache writes + cache reads), how many read over 200K tokens, how many rebuilt the prompt cache (cache writes over half the context, on a context over 20K), the subagents' share, the average output, and the share of all tokens that were context read rather than output
WITH r AS (
  SELECT *, input_tokens + cache_read_tokens + cache_write_tokens AS context
  FROM requests WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
)
SELECT AVG(context) AS avg_context,
       AVG(context > 200000) AS over_200k,
       SUM(cache_write_tokens > 0.5 * context AND context > 20000) AS rebuilds,
       AVG(subagent) AS subagent_share,
       AVG(output_tokens) AS avg_output,
       CAST(SUM(context) AS REAL) / SUM(context + output_tokens) AS read_share
FROM r;

-- name: windows
-- description: Tokens per five-hour usage window, the way Claude plans count usage: a window opens with the first request after the last one closed and lasts five hours. An approximation from the logs, not the plan's own meter.
WITH RECURSIVE r AS (
  SELECT ROW_NUMBER() OVER (ORDER BY ts) AS i, julianday(ts) AS jd,
         input_tokens + cache_read_tokens + cache_write_tokens AS context, output_tokens
  FROM requests WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
), w(i, start) AS (
  SELECT 1, jd FROM r WHERE i = 1
  UNION ALL
  SELECT r.i, CASE WHEN r.jd >= w.start + 5.0 / 24 THEN r.jd ELSE w.start END
  FROM r JOIN w ON r.i = w.i + 1
)
SELECT strftime('%m/%d %H:%M', w.start, 'localtime') AS window,
       SUM(r.context) AS "讀入 context", SUM(r.output_tokens) AS "輸出", COUNT(*) AS requests
FROM w JOIN r ON r.i = w.i
GROUP BY w.start ORDER BY w.start;

-- name: context_sizes
-- description: API requests by how much context each read
WITH r AS (
  SELECT input_tokens + cache_read_tokens + cache_write_tokens AS context
  FROM requests WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
)
SELECT CASE WHEN context < 50000 THEN '5 萬以下' WHEN context < 100000 THEN '5–10 萬' WHEN context < 200000 THEN '10–20 萬'
            WHEN context < 400000 THEN '20–40 萬' WHEN context < 700000 THEN '40–70 萬' ELSE '70 萬以上' END AS size,
       MIN(context) AS low, COUNT(*) AS requests
FROM r GROUP BY size ORDER BY low;

-- name: context_growth
-- description: The context each request read, in order, for the five sessions that read the most in total: how a conversation that is never cleared grows
WITH r AS MATERIALIZED (
  SELECT session_id, ts, input_tokens + cache_read_tokens + cache_write_tokens AS context
  FROM requests WHERE model <> '<synthetic>' AND subagent = 0 AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
), top AS MATERIALIZED (
  SELECT session_id FROM r GROUP BY session_id ORDER BY SUM(context) DESC LIMIT 5
), numbered AS (
  SELECT r.session_id, r.context,
         ROW_NUMBER() OVER (PARTITION BY r.session_id ORDER BY r.ts) AS request,
         COUNT(*) OVER (PARTITION BY r.session_id) AS n
  FROM r JOIN top USING (session_id)
)
-- About 150 points a session: the curve's shape, not every request.
SELECT n.request, s.project || ' · ' || strftime('%m/%d', s.started, 'localtime') AS session, n.context
FROM numbered n JOIN sessions s USING (session_id)
WHERE (n.request - 1) % (n.n / 150 + 1) = 0 OR n.request = n.n
ORDER BY n.request;

-- name: tool_payload
-- description: Characters tool results added to the context, by tool — the ten largest. A result stays in the context and is read again by every later request in the session.
SELECT replace(replace(tool, 'mcp__', ''), '__', ' · ') AS tool, SUM(result_chars) AS chars
FROM tool_calls WHERE date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
GROUP BY tool HAVING chars > 0 ORDER BY chars DESC LIMIT 10;

-- name: images
-- description: Images tool results added to the context (screenshots, image files)
SELECT SUM(result_images) AS images
FROM tool_calls WHERE date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to;

-- name: model_tokens
-- description: Tokens processed (context read + output) by model
SELECT model, SUM(input_tokens + cache_read_tokens + cache_write_tokens + output_tokens) AS tokens
FROM requests WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
GROUP BY model ORDER BY tokens DESC;

-- name: heavy_sessions
-- description: The sessions that processed the most tokens, with what drove them: how long the context got, cache rebuilds, subagent requests and the main model
WITH r AS (
  SELECT *, input_tokens + cache_read_tokens + cache_write_tokens AS context
  FROM requests WHERE model <> '<synthetic>' AND date(ts, 'localtime') >= :from AND date(ts, 'localtime') < :to
)
SELECT strftime('%m/%d %H:%M', s.started, 'localtime') AS started, s.project,
       COUNT(*) AS requests,
       SUM(r.context + r.output_tokens) AS tokens,
       AVG(r.context) AS avg_context,
       MAX(r.context) AS max_context,
       SUM(r.cache_write_tokens > 0.5 * r.context AND r.context > 20000) AS rebuilds,
       SUM(r.subagent) AS subagent_requests,
       (SELECT model FROM r x WHERE x.session_id = s.session_id GROUP BY model ORDER BY COUNT(*) DESC LIMIT 1) AS model
FROM r JOIN sessions s USING (session_id)
GROUP BY s.session_id ORDER BY tokens DESC LIMIT 15;
