-- ====================================================================
-- post_deploy.sql - run AFTER the DCM deploy, as ACCOUNTADMIN, from the Snowsight
-- Workspace (Run All). Covers what DCM cannot DEFINE: git repo, data loads,
-- stage files, Cortex Search service, eval datasets, future grants and SNOWFLAKE roles.
-- Re-runnable: loads TRUNCATE first. Run marketing_agent.sql next.
-- ====================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE AI_AGENT_HOL_WH;

-- Lab role for the person running the lab
SET LAB_USER = CURRENT_USER();
GRANT ROLE AI_AGENT_HOL_ROLE TO USER IDENTIFIER($LAB_USER);

-- Grants DCM does not manage (SNOWFLAKE roles, future grants)
GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE AI_AGENT_HOL_ROLE;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE AI_AGENT_HOL_ROLE;
GRANT APPLICATION ROLE SNOWFLAKE.AI_OBSERVABILITY_EVENTS_LOOKUP TO ROLE AI_AGENT_HOL_ROLE;
GRANT MONITOR ON FUTURE AGENTS IN SCHEMA AI_AGENT_HOL_DB.AGENTS TO ROLE AI_AGENT_HOL_ROLE;
GRANT MONITOR ON FUTURE AGENTS IN SCHEMA AI_AGENT_HOL_DB.AGENTS TO ROLE ACCOUNTADMIN;

-- --------------------------------------------------------------------
-- Git repository + data loads
-- --------------------------------------------------------------------
CREATE OR REPLACE GIT REPOSITORY AI_AGENT_HOL_DB.DATA.CORTEX_AGENT_QUICKSTART_REPO
    API_INTEGRATION = GIT_API_INTEGRATION_AI_AGENT_HOL
    ORIGIN = 'https://github.com/sfc-gh-manvargas/build_deploy_ai_agents_snowflake_cowork_vhol.git';
ALTER GIT REPOSITORY AI_AGENT_HOL_DB.DATA.CORTEX_AGENT_QUICKSTART_REPO FETCH;

TRUNCATE TABLE AI_AGENT_HOL_DB.DATA.CAMPAIGNS;
INSERT INTO AI_AGENT_HOL_DB.DATA.CAMPAIGNS (campaign_id, campaign_name, campaign_type, start_date, end_date, budget_allocated, target_audience, channel, status, created_by)
SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10
FROM @AI_AGENT_HOL_DB.DATA.CORTEX_AGENT_QUICKSTART_REPO/branches/main/data/CAMPAIGNS.csv (FILE_FORMAT => 'AI_AGENT_HOL_DB.DATA.AGENT_EVAL_QUICKSTART_CSV_FORMAT');

TRUNCATE TABLE AI_AGENT_HOL_DB.DATA.CAMPAIGN_PERFORMANCE;
INSERT INTO AI_AGENT_HOL_DB.DATA.CAMPAIGN_PERFORMANCE (performance_id, campaign_id, date, impressions, clicks, conversions, cost_per_click, cost_per_acquisition, revenue_generated, roi_percentage, engagement_rate)
SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11
FROM @AI_AGENT_HOL_DB.DATA.CORTEX_AGENT_QUICKSTART_REPO/branches/main/data/CAMPAIGN_PERFORMANCE.csv (FILE_FORMAT => 'AI_AGENT_HOL_DB.DATA.AGENT_EVAL_QUICKSTART_CSV_FORMAT');

TRUNCATE TABLE AI_AGENT_HOL_DB.DATA.CAMPAIGN_CONTENT;
INSERT INTO AI_AGENT_HOL_DB.DATA.CAMPAIGN_CONTENT (campaign_id, content_type, campaign_description, marketing_copy, a_b_test_notes)
SELECT $1, $2, $3, $4, $5
FROM @AI_AGENT_HOL_DB.DATA.CORTEX_AGENT_QUICKSTART_REPO/branches/main/data/CAMPAIGN_CONTENT.csv (FILE_FORMAT => 'AI_AGENT_HOL_DB.DATA.AGENT_EVAL_QUICKSTART_CSV_FORMAT');

TRUNCATE TABLE AI_AGENT_HOL_DB.DATA.CAMPAIGN_FEEDBACK;
INSERT INTO AI_AGENT_HOL_DB.DATA.CAMPAIGN_FEEDBACK (feedback_id, campaign_id, feedback_date, customer_segment, satisfaction_score, detailed_comments, survey_responses, recommended_improvements)
SELECT $1, $2, $3, $4, $5, $6, $7, $8
FROM @AI_AGENT_HOL_DB.DATA.CORTEX_AGENT_QUICKSTART_REPO/branches/main/data/CAMPAIGN_FEEDBACK.csv (FILE_FORMAT => 'AI_AGENT_HOL_DB.DATA.AGENT_EVAL_QUICKSTART_CSV_FORMAT');

-- Dev / held-out split (10 / 5). One held-out question per question type:
-- report, multi-dimension analytics, superlative quant+qual, out-of-scope refusal, web search.
-- Tune instructions on DEV only; HOLDOUT decides whether a candidate version is promoted.
-- NOTE: 15 rows is teaching-sized; production evals typically need far more rows per split.
TRUNCATE TABLE AI_AGENT_HOL_DB.DATA.EVALS_TABLE;
INSERT INTO AI_AGENT_HOL_DB.DATA.EVALS_TABLE (input_query, ground_truth_data, split)
SELECT $1, PARSE_JSON($2),
    CASE
        WHEN $1 ILIKE 'Generate a report for campaign #12%'
          OR $1 ILIKE 'What''s the relationship between campaign duration%'
          OR $1 ILIKE 'For the campaign with the highest engagement%'
          OR $1 ILIKE 'How many iphones%'
          OR $1 ILIKE 'Based on Pew Research Center%'
        THEN 'HOLDOUT'
        ELSE 'DEV'
    END
FROM @AI_AGENT_HOL_DB.DATA.CORTEX_AGENT_QUICKSTART_REPO/branches/main/data/EVALS_TABLE.csv (FILE_FORMAT => 'AI_AGENT_HOL_DB.DATA.AGENT_EVAL_QUICKSTART_CSV_FORMAT');

TRUNCATE TABLE AI_AGENT_HOL_DB.DATA.EVALS_TABLE_DEV;
INSERT INTO AI_AGENT_HOL_DB.DATA.EVALS_TABLE_DEV (input_query, ground_truth_data)
SELECT input_query, ground_truth_data FROM AI_AGENT_HOL_DB.DATA.EVALS_TABLE WHERE split = 'DEV';

TRUNCATE TABLE AI_AGENT_HOL_DB.DATA.EVALS_TABLE_HOLDOUT;
INSERT INTO AI_AGENT_HOL_DB.DATA.EVALS_TABLE_HOLDOUT (input_query, ground_truth_data)
SELECT input_query, ground_truth_data FROM AI_AGENT_HOL_DB.DATA.EVALS_TABLE WHERE split = 'HOLDOUT';

-- --------------------------------------------------------------------
-- Agent skill + eval configs, copied from the lab Git repo
-- --------------------------------------------------------------------
COPY FILES INTO @AI_AGENT_HOL_DB.AGENTS.AGENT_SKILLS/skills/campaign-report/
    FROM @AI_AGENT_HOL_DB.DATA.CORTEX_AGENT_QUICKSTART_REPO/branches/main/dcm_project/files/skills/campaign-report/
    FILES = ('SKILL.md', 'render_report.py');
COPY FILES INTO @AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE
    FROM @AI_AGENT_HOL_DB.DATA.CORTEX_AGENT_QUICKSTART_REPO/branches/main/dcm_project/files/evals/
    FILES = ('eval_v1_dev.yaml',
             'eval_v2_dev.yaml',
             'eval_v1_holdout.yaml',
             'eval_v2_holdout.yaml');
ALTER STAGE AI_AGENT_HOL_DB.AGENTS.AGENT_SKILLS REFRESH;
ALTER STAGE AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE REFRESH;

-- --------------------------------------------------------------------
-- Objects owned by the lab role
-- --------------------------------------------------------------------
USE ROLE AI_AGENT_HOL_ROLE;
USE WAREHOUSE AI_AGENT_HOL_WH;

CREATE OR REPLACE CORTEX SEARCH SERVICE AI_AGENT_HOL_DB.ANALYTICS.MARKETING_CAMPAIGNS_SEARCH
  ON combined_text
  ATTRIBUTES campaign_name, campaign_type, channel, content_type
  WAREHOUSE = AI_AGENT_HOL_WH
  TARGET_LAG = '1 hour'
  AS (
    SELECT 
      c.campaign_id,
      c.campaign_name,
      c.campaign_type,
      c.channel,
      cnt.content_type,
      CONCAT(
        'Campaign: ', c.campaign_name, '. ',
        'Type: ', c.campaign_type, '. ',
        'Channel: ', c.channel, '. ',
        'Description: ', cnt.campaign_description, '. ',
        'Marketing Copy: ', cnt.marketing_copy, '. ',
        'A/B Test Notes: ', cnt.a_b_test_notes
      ) as combined_text
    FROM AI_AGENT_HOL_DB.DATA.CAMPAIGNS c
    JOIN AI_AGENT_HOL_DB.DATA.CAMPAIGN_CONTENT cnt ON c.campaign_id = cnt.campaign_id
    
    UNION ALL
    
    SELECT 
      c.campaign_id,
      c.campaign_name,
      c.campaign_type,
      c.channel,
      'feedback' as content_type,
      CONCAT(
        'Campaign: ', c.campaign_name, '. ',
        'Customer Segment: ', fb.customer_segment, '. ',
        'Satisfaction Score: ', fb.satisfaction_score, '. ',
        'Comments: ', fb.detailed_comments, '. ',
        'Improvements: ', fb.recommended_improvements
      ) as combined_text
    FROM AI_AGENT_HOL_DB.DATA.CAMPAIGNS c
    JOIN AI_AGENT_HOL_DB.DATA.CAMPAIGN_FEEDBACK fb ON c.campaign_id = fb.campaign_id
  );

-- Cortex Agent: not DEFINE-able in DCM, managed in marketing_agent.sql (run after this script).

-- Evaluation datasets: DEV (tune) and HOLDOUT (decide). The DEV baseline runs from marketing_agent.sql;
-- held-out runs wait until a candidate is frozen (see evaluate_holdout.sql).
-- Drop first so re-runs don't fail with "Dataset version ... already exists".
DROP DATASET IF EXISTS AI_AGENT_HOL_DB.AGENTS.MARKETING_CAMPAIGN_EVALSET_DEV;
DROP DATASET IF EXISTS AI_AGENT_HOL_DB.AGENTS.MARKETING_CAMPAIGN_EVALSET_HOLDOUT;

CALL SYSTEM$CREATE_EVALUATION_DATASET(
    'Cortex Agent',
    'AI_AGENT_HOL_DB.DATA.EVALS_TABLE_DEV',
    'AI_AGENT_HOL_DB.AGENTS.MARKETING_CAMPAIGN_EVALSET_DEV',
    OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'GROUND_TRUTH_DATA'));

CALL SYSTEM$CREATE_EVALUATION_DATASET(
    'Cortex Agent',
    'AI_AGENT_HOL_DB.DATA.EVALS_TABLE_HOLDOUT',
    'AI_AGENT_HOL_DB.AGENTS.MARKETING_CAMPAIGN_EVALSET_HOLDOUT',
    OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'GROUND_TRUTH_DATA'));

-- Baseline DEV eval run is started from marketing_agent.sql once the agent exists.
