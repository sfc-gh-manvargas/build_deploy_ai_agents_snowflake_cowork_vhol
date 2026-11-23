-- ====================================================================
-- marketing_agent_v2.sql - VERSION$2 of the Cortex Agent
-- AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT: improved orchestration + response
-- instructions (tools, tool_resources, skills, models unchanged from VERSION$1),
-- plus the DEV candidate eval run against VERSION$2.
-- Instructions fix failure patterns found in eval run MARKETING_AGENT_V1_DEV_R02:
--   1. invalid-identifier SQL retries (metric names used as columns, SUM(budget))
--   2. "most alike" answered with metric distance instead of campaign content
--   3. campaign-report fetched metrics with raw SQL instead of query_performance_metrics
--   4. weak "most compelling" pick on qualitative A/B results
--   5. leaked reasoning / raw JSON / off-topic capability answer
--   6. trend answers missing weekly / day-of-week patterns
-- Run order: marketing_agent_v1_baseline.sql -> this script.
-- NOT idempotent: each run commits a new version (VERSION$2, then VERSION$3, ...).
-- VERSION$1 (alias BASELINE) is never overwritten.
-- ====================================================================

USE ROLE AI_AGENT_HOL_ROLE;
USE WAREHOUSE AI_AGENT_HOL_WH;
USE SCHEMA AI_AGENT_HOL_DB.AGENTS;

-- --------------------------------------------------------------------
-- 1. Versions before the change
-- --------------------------------------------------------------------
SHOW VERSIONS IN AGENT AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT;

-- --------------------------------------------------------------------
-- 2. Update the LIVE version spec (instructions only) and commit it
-- --------------------------------------------------------------------
-- If no live version exists yet, create one first:
--   ALTER AGENT AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT ADD LIVE VERSION FROM LAST;
ALTER AGENT AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT
  MODIFY LIVE VERSION SET SPECIFICATION = $$
{
    "models": {
        "orchestration": "claude-sonnet-5"
    },
    "instructions": {
        "response": "- Lead with a direct one- or two-sentence answer (name the winning campaign/channel and its key number), then supporting detail.\n- Use short sections or bullets. Use a markdown table when comparing 3+ items or listing several metrics; do not paste raw JSON result dumps.\n- Cite figures exactly as returned by tools, with units (%, $, counts) and the time period covered. Never invent or estimate numbers. State date ranges precisely (e.g., \"May 20-22, 2024\"), not a derived duration that could be wrong.\n- For \"best\"/\"most\" questions, commit to one answer and give the reason; mention at most one runner-up.\n- For similarity questions, name the two campaigns and explain the shared purpose, type, channel, audience and messaging.\n- For trend questions, describe the overall shape (ramp, peak, decline) with values, plus any weekly/day-of-week pattern found.\n- For qualitative answers, ground every claim in retrieved content and name the source campaign.\n- For report requests, give the report location, then headline metrics and 3-5 key insights.\n- For web_search answers, summarize the key points and cite the source.\n- For capability questions, describe only this agent's marketing capabilities: campaign performance metrics and trends, campaign content insights (feedback, A/B tests, messaging), campaign reports, and external marketing/regulatory research. Give 3-4 example questions. Do not list generic platform or bundled skills (e.g., SQL migration, HTML authoring).\n- Never include internal reasoning, SQL errors, retries or tool mechanics in the answer (no \"Need to use base column names...\", no \"Now rendering...\").\n",
        "orchestration": "You are a marketing campaign analytics agent. Choose the smallest set of tools that fully answers the question and make as few calls as possible.\n\n## Step 1 - Classify the question, then route\n- Quantitative (performance of a campaign, rankings by a metric, CTR/ROI/CPA/revenue, trends over time): query_performance_metrics ONLY.\n- Qualitative (feedback, A/B tests, themes, messaging, descriptions, recommendations, how campaigns are similar or different): search_campaign_content ONLY.\n- Mixed (asks for themes/feedback/content AND numbers): search_campaign_content and query_performance_metrics, one call each, issued in parallel, then combine.\n- External/public knowledge (regulations, FTC/industry guidance, competitors, benchmarks): web_search ONLY, unless the user also asks to apply it to our campaign data.\n- Report requests (\"generate/create a report for <campaign>\"): use the campaign-report skill.\n- Capability questions (\"what can you help me with?\"): answer directly with NO tools.\n\n## Similarity / \"most alike\" questions\nCampaigns are alike when they share purpose, type, channel, audience, seasonality and messaging. Answer from search_campaign_content descriptions. Do NOT compute numeric distances over performance metrics and do NOT use code_execution for this.\n\n## \"Best / most compelling\" over qualitative content\nCompare every candidate returned by search on the measured outcome (size of lift, absolute open/click/conversion results, business impact), prefer results with concrete percentages over anecdotal ones, and pick the single strongest one.\n\n## Report requests (order)\n1. query_performance_metrics once: identify the campaign and return all its metrics in one query.\n2. search_campaign_content once: feedback, A/B tests, description.\n3. Render the report per the skill. Never fetch metrics with raw SQL execution tools; all numbers come from query_performance_metrics.\n\n## Efficient query_performance_metrics calls\n- Aim for ONE successful call. Request every metric and dimension needed in a single question/query rather than several small ones.\n- Semantic metric names (total_clicks, total_impressions, total_conversions, total_revenue, total_budget, avg_roi, avg_cost_per_click, avg_cost_per_acquisition, avg_engagement_rate, campaign_count) are NOT physical columns and cannot be prefixed with a table alias. Aggregate the base columns: SUM(clicks), SUM(impressions), SUM(conversions), SUM(revenue_generated), AVG(roi_percentage), AVG(cost_per_click), AVG(cost_per_acquisition), AVG(engagement_rate).\n- Budget is a campaign-level attribute: take budget_allocated once per campaign; never SUM it across daily performance rows (that inflates it).\n- Compute ratios as ratios of sums, e.g. CTR = SUM(clicks)/SUM(impressions).\n- For trend questions, return monthly totals and also day-of-week / weekly patterns in the same call when feasible.\n- If a call fails with \"invalid identifier\", fix ALL columns against the semantic model at once before retrying. Never repeat the same mistake; maximum two attempts.\n\n## Other tools\n- web_search: one precise query; search again only if the first results lack the answer.\n- code_execution: only for a computation or chart that query_performance_metrics cannot return. Never as a substitute for search on qualitative questions.\n",
        "sample_questions": [
            {
                "question": "What campaigns have the highest ROI?"
            }
        ]
    },
    "tools": [
        {
            "tool_spec": {
                "type": "cortex_analyst_text_to_sql",
                "name": "query_performance_metrics",
                "description": "Query structured performance data including campaign ROI, revenue, budget efficiency, impressions, clicks, conversions, cost metrics, and engagement rates. Use for quantitative analysis of campaign performance across channels and time periods."
            }
        },
        {
            "tool_spec": {
                "type": "cortex_search",
                "name": "search_campaign_content",
                "description": "Search unstructured campaign content including campaign descriptions, marketing copy, A/B test results, customer feedback, and recommended improvements. Use for qualitative insights, content discovery, and learning from past campaigns."
            }
        },
        {
            "tool_spec": {
                "type": "code_execution",
                "name": "code_execution"
            }
        },
        {
            "tool_spec": {
                "type": "web_search",
                "name": "web_search"
            }
        }
    ],
    "skills": [
        {
            "name": "campaign-report",
            "source": {
                "type": "STAGE",
                "path": "@AI_AGENT_HOL_DB.AGENTS.AGENT_SKILLS/skills/campaign-report"
            }
        }
    ],
    "tool_resources": {
        "query_performance_metrics": {
            "execution_environment": {
                "query_timeout": 299,
                "type": "warehouse",
                "warehouse": "AI_AGENT_HOL_WH"
            },
            "semantic_view": "AI_AGENT_HOL_DB.ANALYTICS.MARKETING_PERFORMANCE_ANALYST"
        },
        "search_campaign_content": {
            "execution_environment": {
                "query_timeout": 299,
                "type": "warehouse",
                "warehouse": "AI_AGENT_HOL_WH"
            },
            "search_service": "AI_AGENT_HOL_DB.ANALYTICS.MARKETING_CAMPAIGNS_SEARCH"
        },
        "code_execution": {
            "permission_policy": {
                "type": "always_allow"
            }
        }
    }
}

$$;

-- Commit LIVE as the next numbered version (VERSION$2); it becomes the default.
ALTER AGENT AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT COMMIT;

-- Optional: keep BASELINE as default until VERSION$2 is validated
-- ALTER AGENT AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT SET DEFAULT_VERSION = 'VERSION$1';

-- --------------------------------------------------------------------
-- 3. Versions after the change
-- --------------------------------------------------------------------
SHOW VERSIONS IN AGENT AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT;

-- --------------------------------------------------------------------
-- 4. DEV candidate eval against VERSION$2
-- --------------------------------------------------------------------
-- eval_v2_dev.yaml pins agent_version: VERSION$2 and dataset
-- AI_AGENT_HOL_DB.AGENTS.MARKETING_CAMPAIGN_EVALSET_DEV.
-- Run names cannot be reused: MARKETING_AGENT_V2_DEV_R01 was already consumed
-- (it FAILED with "batch agent API ... client error"), so bump the suffix on re-runs.
-- The eval calls the agent as the session's PRIMARY role only (secondary roles are
-- ignored). It needs USAGE/OWNERSHIP on the agent; ACCOUNTADMIN only has MONITOR, so
-- starting the run as ACCOUNTADMIN fails with 401 / error 399513 "The agent does not
-- exist or access is not authorized for the current role" (MARKETING_AGENT_V2_DEV_R01).
-- Always START evals as the owner role AI_AGENT_HOL_ROLE.
USE ROLE ACCOUNTADMIN;
GRANT MONITOR ON AGENT AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT TO ROLE ACCOUNTADMIN;
USE ROLE AI_AGENT_HOL_ROLE;
USE WAREHOUSE AI_AGENT_HOL_WH;
USE SCHEMA AI_AGENT_HOL_DB.AGENTS;

-- Pre-flight: stop here unless this returns AI_AGENT_HOL_ROLE, and the agent answers.
SELECT CURRENT_ROLE() AS eval_role,
       IFF(CURRENT_ROLE() = 'AI_AGENT_HOL_ROLE', 'OK', 'WRONG ROLE - do not start the eval') AS check_role;
SELECT LEFT(SNOWFLAKE.CORTEX.DATA_AGENT_RUN('AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT',
  '{"messages":[{"role":"user","content":[{"type":"text","text":"What can you help me with?"}]}],"stream":false}')::string, 300) AS agent_smoke_test;

CALL EXECUTE_AI_EVALUATION(
  'START',
  OBJECT_CONSTRUCT('run_name', 'MARKETING_AGENT_V2_DEV_R01'),
  '@AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE/eval_v2_dev.yaml'
);

-- Poll until STATUS = COMPLETED
CALL EXECUTE_AI_EVALUATION(
  'STATUS',
  OBJECT_CONSTRUCT('run_name', 'MARKETING_AGENT_V2_DEV_R01'),
  '@AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE/eval_v2_dev.yaml'
);

-- --------------------------------------------------------------------
-- 5. Compare V2 candidate vs V1 baseline: scores by metric
-- --------------------------------------------------------------------
WITH s AS (
  SELECT record_attributes:"snow.ai.observability.run.name"::string AS run_name,
         record_attributes:"ai.observability.eval.metric_name"::string AS metric_name,
         record_attributes:"ai.observability.eval_root.score"::float AS score
  FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(
    'AI_AGENT_HOL_DB', 'AGENTS', 'MARKETING_AGENT', 'CORTEX AGENT'))
  WHERE record_attributes:"ai.observability.span_type"::string = 'eval_root'
    AND record_attributes:"snow.ai.observability.run.name"::string
        IN ('MARKETING_AGENT_V1_DEV_R02', 'MARKETING_AGENT_V2_DEV_R01')
)
SELECT metric_name,
       ROUND(AVG(IFF(run_name = 'MARKETING_AGENT_V1_DEV_R02', score, NULL)), 3) AS v1_avg,
       ROUND(AVG(IFF(run_name = 'MARKETING_AGENT_V2_DEV_R01', score, NULL)), 3) AS v2_avg,
       ROUND(v2_avg - v1_avg, 3) AS delta
FROM s
GROUP BY metric_name
ORDER BY metric_name;

-- --------------------------------------------------------------------
-- 6. Per-question answer_correctness: improved / same / regressed
-- --------------------------------------------------------------------
WITH e AS (
  SELECT record_attributes AS r
  FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(
    'AI_AGENT_HOL_DB', 'AGENTS', 'MARKETING_AGENT', 'CORTEX AGENT'))
  WHERE r:"snow.ai.observability.run.name"::string
        IN ('MARKETING_AGENT_V1_DEV_R02', 'MARKETING_AGENT_V2_DEV_R01')
),
q AS (
  SELECT r:"snow.ai.observability.run.name"::string AS run_name,
         r:"ai.observability.record_id"::string AS record_id,
         ANY_VALUE(r:"ai.observability.record_root.input"::string) AS question
  FROM e WHERE r:"ai.observability.span_type"::string = 'record_root'
  GROUP BY 1, 2
),
sc AS (
  SELECT r:"snow.ai.observability.run.name"::string AS run_name,
         r:"ai.observability.eval.target_record_id"::string AS record_id,
         r:"ai.observability.eval_root.score"::float AS score
  FROM e WHERE r:"ai.observability.span_type"::string = 'eval_root'
    AND r:"ai.observability.eval.metric_name"::string = 'answer_correctness'
),
by_q AS (  -- record IDs differ across runs, so match on question text
  SELECT q.question,
         MAX(IFF(q.run_name = 'MARKETING_AGENT_V1_DEV_R02', sc.score, NULL)) AS v1_ac,
         MAX(IFF(q.run_name = 'MARKETING_AGENT_V2_DEV_R01', sc.score, NULL)) AS v2_ac
  FROM q JOIN sc ON sc.run_name = q.run_name AND sc.record_id = q.record_id
  GROUP BY q.question
)
SELECT question, v1_ac, v2_ac,
       CASE WHEN v1_ac >= 0.80 AND v2_ac < 0.40 THEN 'REGRESSED (pass -> fail)'
            WHEN v2_ac > v1_ac THEN 'IMPROVED'
            WHEN v2_ac < v1_ac THEN 'WORSE'
            ELSE 'SAME' END AS change
FROM by_q
ORDER BY change, question;
