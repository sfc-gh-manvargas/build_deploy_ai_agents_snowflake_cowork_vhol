-- ====================================================================
-- marketing_agent_v3.sql - VERSION$3 of the Cortex Agent
-- AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT: semantic view fix.
-- Instructions are identical to VERSION$2; the only spec change is
-- tool_resources.query_performance_metrics.semantic_view, which now points to a NEW
-- semantic view MARKETING_PERFORMANCE_ANALYST_V3. The original view is untouched,
-- so VERSION$1 / VERSION$2 (and their eval runs) stay reproducible.
-- The V3 view fixes the R02 SQL failures:
--   - base columns exposed as FACTS (no more "invalid identifier" guesses)
--   - CLICK_THROUGH_RATE / CONVERSION_RATE as ratios of sums, RETURN_ON_AD_SPEND
--   - TOTAL_BUDGET at campaign grain (not inflated by daily rows)
--   - synonyms (CTR, clickrate, ROI, ...) and comments on every field
--   - PERFORMANCE_MONTH / PERFORMANCE_WEEK / DAY_OF_WEEK for trend questions
--   - AI_SQL_GENERATION guidance for Cortex Analyst
-- Run order: marketing_agent_v1_baseline.sql -> marketing_agent_v2.sql -> this script.
-- NOT idempotent: each run commits a new agent version. Earlier versions are never overwritten.
-- Prerequisite: upload dcm_project/eval_v3_dev.yaml (copy of eval_v2_dev.yaml with
-- agent_version: VERSION$3) to @AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE/ (section 4).
-- ====================================================================

USE ROLE AI_AGENT_HOL_ROLE;
USE WAREHOUSE AI_AGENT_HOL_WH;
USE SCHEMA AI_AGENT_HOL_DB.AGENTS;

-- --------------------------------------------------------------------
-- 1. New semantic view (original MARKETING_PERFORMANCE_ANALYST is not modified)
-- --------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW AI_AGENT_HOL_DB.ANALYTICS.MARKETING_PERFORMANCE_ANALYST_V3
  TABLES (
    CAMPAIGNS AS AI_AGENT_HOL_DB.DATA.CAMPAIGNS PRIMARY KEY (CAMPAIGN_ID)
      WITH SYNONYMS = ('campaign', 'marketing campaign')
      COMMENT = 'One row per marketing campaign: name, type, channel, audience, dates and allocated budget.',
    PERFORMANCE AS AI_AGENT_HOL_DB.DATA.CAMPAIGN_PERFORMANCE PRIMARY KEY (PERFORMANCE_ID)
      WITH SYNONYMS = ('daily performance', 'campaign results')
      COMMENT = 'One row per campaign per day: impressions, clicks, conversions, revenue and cost/efficiency rates.'
  )
  RELATIONSHIPS (
    PERFORMANCE_TO_CAMPAIGNS AS PERFORMANCE (CAMPAIGN_ID) REFERENCES CAMPAIGNS (CAMPAIGN_ID)
  )
  FACTS (
    CAMPAIGNS.BUDGET_ALLOCATED AS budget_allocated
      COMMENT = 'Budget allocated to the campaign (campaign-level; one value per campaign, never sum across daily rows).',
    PERFORMANCE.IMPRESSIONS AS impressions COMMENT = 'Impressions served on that day.',
    PERFORMANCE.CLICKS AS clicks COMMENT = 'Clicks on that day.',
    PERFORMANCE.CONVERSIONS AS conversions COMMENT = 'Conversions on that day.',
    PERFORMANCE.REVENUE_GENERATED AS revenue_generated COMMENT = 'Revenue attributed on that day, in USD.',
    PERFORMANCE.COST_PER_CLICK AS cost_per_click COMMENT = 'Daily cost per click, in USD.',
    PERFORMANCE.COST_PER_ACQUISITION AS cost_per_acquisition COMMENT = 'Daily cost per acquisition, in USD.',
    PERFORMANCE.ROI_PERCENTAGE AS roi_percentage COMMENT = 'Daily ROI, in percent.',
    PERFORMANCE.ENGAGEMENT_RATE AS engagement_rate COMMENT = 'Daily engagement rate, in percent.'
  )
  DIMENSIONS (
    CAMPAIGNS.CAMPAIGN_ID AS campaign_id COMMENT = 'Unique campaign identifier.',
    CAMPAIGNS.CAMPAIGN_NAME AS campaign_name
      WITH SYNONYMS = ('campaign', 'campaign title')
      COMMENT = 'Campaign display name, e.g. a seasonal sale or product launch. Match user wording with ILIKE.',
    CAMPAIGNS.CAMPAIGN_TYPE AS campaign_type WITH SYNONYMS = ('campaign category', 'objective') COMMENT = 'Campaign type / objective.',
    CAMPAIGNS.CHANNEL AS channel WITH SYNONYMS = ('marketing channel', 'medium') COMMENT = 'Marketing channel (e.g. email, social, search, display).',
    CAMPAIGNS.TARGET_AUDIENCE AS target_audience WITH SYNONYMS = ('audience', 'segment') COMMENT = 'Intended audience segment.',
    CAMPAIGNS.STATUS AS status COMMENT = 'Campaign lifecycle status.',
    CAMPAIGNS.START_DATE AS start_date COMMENT = 'Campaign start date.',
    CAMPAIGNS.END_DATE AS end_date COMMENT = 'Campaign end date.',
    CAMPAIGNS.CREATED_BY AS created_by COMMENT = 'Owner who created the campaign.',
    PERFORMANCE.DATE AS date WITH SYNONYMS = ('day', 'performance date') COMMENT = 'Calendar date of the performance row.',
    PERFORMANCE.PERFORMANCE_MONTH AS DATE_TRUNC('month', date) WITH SYNONYMS = ('month') COMMENT = 'Month of the performance date, for monthly trends.',
    PERFORMANCE.PERFORMANCE_WEEK AS DATE_TRUNC('week', date) WITH SYNONYMS = ('week') COMMENT = 'Week of the performance date, for weekly trends.',
    PERFORMANCE.DAY_OF_WEEK AS DAYNAME(date) WITH SYNONYMS = ('weekday') COMMENT = 'Day-of-week name (Mon..Sun), for day-of-week patterns.'
  )
  METRICS (
    PERFORMANCE.TOTAL_REVENUE AS SUM(performance.revenue_generated) WITH SYNONYMS = ('revenue', 'sales') COMMENT = 'Total revenue in USD.',
    PERFORMANCE.TOTAL_IMPRESSIONS AS SUM(performance.impressions) WITH SYNONYMS = ('impressions', 'views') COMMENT = 'Total impressions.',
    PERFORMANCE.TOTAL_CLICKS AS SUM(performance.clicks) WITH SYNONYMS = ('clicks') COMMENT = 'Total clicks.',
    PERFORMANCE.TOTAL_CONVERSIONS AS SUM(performance.conversions) WITH SYNONYMS = ('conversions', 'acquisitions') COMMENT = 'Total conversions.',
    PERFORMANCE.CLICK_THROUGH_RATE AS DIV0(SUM(performance.clicks), SUM(performance.impressions))
      WITH SYNONYMS = ('CTR', 'click rate', 'clickrate', 'click-through rate')
      COMMENT = 'Clicks divided by impressions (ratio of sums, 0-1).',
    PERFORMANCE.CONVERSION_RATE AS DIV0(SUM(performance.conversions), SUM(performance.clicks))
      WITH SYNONYMS = ('CVR', 'conversion rate') COMMENT = 'Conversions divided by clicks (ratio of sums, 0-1).',
    PERFORMANCE.AVG_COST_PER_CLICK AS AVG(performance.cost_per_click) WITH SYNONYMS = ('CPC') COMMENT = 'Average daily cost per click, USD.',
    PERFORMANCE.AVG_COST_PER_ACQUISITION AS AVG(performance.cost_per_acquisition) WITH SYNONYMS = ('CPA') COMMENT = 'Average daily cost per acquisition, USD.',
    PERFORMANCE.AVG_ROI AS AVG(performance.roi_percentage) WITH SYNONYMS = ('ROI', 'return on investment') COMMENT = 'Average daily ROI, percent.',
    PERFORMANCE.AVG_ENGAGEMENT_RATE AS AVG(performance.engagement_rate) WITH SYNONYMS = ('engagement', 'engagement rate') COMMENT = 'Average daily engagement rate, percent.',
    CAMPAIGNS.TOTAL_BUDGET AS SUM(campaigns.budget_allocated)
      WITH SYNONYMS = ('budget', 'spend budget')
      COMMENT = 'Total allocated budget in USD, summed once per campaign (campaign grain, not daily rows).',
    CAMPAIGNS.CAMPAIGN_COUNT AS COUNT(campaigns.campaign_id) WITH SYNONYMS = ('number of campaigns') COMMENT = 'Number of campaigns.',
    RETURN_ON_AD_SPEND AS DIV0(PERFORMANCE.TOTAL_REVENUE, CAMPAIGNS.TOTAL_BUDGET)
      WITH SYNONYMS = ('ROAS', 'revenue per budget dollar') COMMENT = 'Total revenue divided by total allocated budget.'
  )
  COMMENT = 'V3: marketing campaign performance with facts, synonyms, derived rates and time grains.'
  AI_SQL_GENERATION 'Use the defined metrics (TOTAL_CLICKS, CLICK_THROUGH_RATE, TOTAL_BUDGET, ...) instead of re-aggregating facts. Compute rates as ratios of sums, never averages of daily rates. TOTAL_BUDGET is campaign-level; never sum budget_allocated over daily performance rows. Match campaign names with ILIKE on campaign_name. For trends use PERFORMANCE_MONTH, PERFORMANCE_WEEK or DAY_OF_WEEK.';

-- Sanity check: CTR as ratio of sums, budget counted once per campaign
SELECT * FROM SEMANTIC_VIEW(
  AI_AGENT_HOL_DB.ANALYTICS.MARKETING_PERFORMANCE_ANALYST_V3
  DIMENSIONS campaigns.channel
  METRICS performance.click_through_rate, campaigns.total_budget, return_on_ad_spend
) ORDER BY click_through_rate DESC;

-- --------------------------------------------------------------------
-- 2. Versions before the change
-- --------------------------------------------------------------------
SHOW VERSIONS IN AGENT AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT;

-- --------------------------------------------------------------------
-- 3. Point LIVE at the V3 semantic view (instructions = VERSION$2) and commit
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
            "semantic_view": "AI_AGENT_HOL_DB.ANALYTICS.MARKETING_PERFORMANCE_ANALYST_V3"
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

-- Commit LIVE as the next numbered version (VERSION$3); it becomes the default.
ALTER AGENT AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT COMMIT;

-- Optional: keep BASELINE as default until VERSION$3 is validated
-- ALTER AGENT AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT SET DEFAULT_VERSION = 'VERSION$1';

SHOW VERSIONS IN AGENT AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT;

-- --------------------------------------------------------------------
-- 4. Eval config: eval_v3_dev.yaml = eval_v2_dev.yaml with agent_version: VERSION$3
-- --------------------------------------------------------------------
-- The file is in this workspace at dcm_project/eval_v3_dev.yaml. Upload it to the stage, e.g.
-- from Snowflake CLI:
--   snow stage copy dcm_project/eval_v3_dev.yaml @AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE/ --overwrite
-- or Snowsight: Data > AI_AGENT_HOL_DB.AGENTS > EVAL_CONFIG_STAGE > + Files.
LIST @AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE PATTERN = '.*eval_v3_dev.yaml';

-- --------------------------------------------------------------------
-- 5. DEV candidate eval against VERSION$3
-- --------------------------------------------------------------------
-- Run names cannot be reused; bump the suffix (R02, R03, ...) on re-runs.
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
  OBJECT_CONSTRUCT('run_name', 'MARKETING_AGENT_V3_DEV_R01'),
  '@AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE/eval_v3_dev.yaml'
);

-- Poll until STATUS = COMPLETED
CALL EXECUTE_AI_EVALUATION(
  'STATUS',
  OBJECT_CONSTRUCT('run_name', 'MARKETING_AGENT_V3_DEV_R01'),
  '@AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE/eval_v3_dev.yaml'
);

-- --------------------------------------------------------------------
-- 6. Compare V3 candidate vs V1 baseline: scores by metric
-- --------------------------------------------------------------------
WITH s AS (
  SELECT record_attributes:"snow.ai.observability.run.name"::string AS run_name,
         record_attributes:"ai.observability.eval.metric_name"::string AS metric_name,
         record_attributes:"ai.observability.eval_root.score"::float AS score
  FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(
    'AI_AGENT_HOL_DB', 'AGENTS', 'MARKETING_AGENT', 'CORTEX AGENT'))
  WHERE record_attributes:"ai.observability.span_type"::string = 'eval_root'
    AND record_attributes:"snow.ai.observability.run.name"::string
        IN ('MARKETING_AGENT_V1_DEV_R02', 'MARKETING_AGENT_V3_DEV_R01')
)
SELECT metric_name,
       ROUND(AVG(IFF(run_name = 'MARKETING_AGENT_V1_DEV_R02', score, NULL)), 3) AS v1_avg,
       ROUND(AVG(IFF(run_name = 'MARKETING_AGENT_V3_DEV_R01', score, NULL)), 3) AS v3_avg,
       ROUND(v3_avg - v1_avg, 3) AS delta
FROM s
GROUP BY metric_name
ORDER BY metric_name;

-- --------------------------------------------------------------------
-- 7. Per-question answer_correctness: improved / same / regressed
-- --------------------------------------------------------------------
WITH e AS (
  SELECT record_attributes AS r
  FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(
    'AI_AGENT_HOL_DB', 'AGENTS', 'MARKETING_AGENT', 'CORTEX AGENT'))
  WHERE r:"snow.ai.observability.run.name"::string
        IN ('MARKETING_AGENT_V1_DEV_R02', 'MARKETING_AGENT_V3_DEV_R01')
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
         MAX(IFF(q.run_name = 'MARKETING_AGENT_V3_DEV_R01', sc.score, NULL)) AS v3_ac
  FROM q JOIN sc ON sc.run_name = q.run_name AND sc.record_id = q.record_id
  GROUP BY q.question
)
SELECT question, v1_ac, v3_ac,
       CASE WHEN v1_ac >= 0.80 AND v3_ac < 0.40 THEN 'REGRESSED (pass -> fail)'
            WHEN v3_ac > v1_ac THEN 'IMPROVED'
            WHEN v3_ac < v1_ac THEN 'WORSE'
            ELSE 'SAME' END AS change
FROM by_q
ORDER BY change, question;
