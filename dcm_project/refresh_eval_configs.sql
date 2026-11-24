-- ====================================================================
-- Refresh eval configs on EVAL_CONFIG_STAGE and re-run the DEV baseline
-- Use after editing files/evals/*.yaml (e.g. the campaign_* metric rename).
-- Run in the lab account. Do NOT re-run all of post_deploy.sql for this.
-- ====================================================================
USE ROLE AI_AGENT_HOL_ROLE;
USE WAREHOUSE AI_AGENT_HOL_WH;
USE SCHEMA AI_AGENT_HOL_DB.AGENTS;

-- 1. Pull latest commits from GitHub into the repo stage
ALTER GIT REPOSITORY AI_AGENT_HOL_DB.DATA.CORTEX_AGENT_QUICKSTART_REPO FETCH;

-- 2. Purge stale eval configs (COPY FILES may not overwrite)
REMOVE @AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE/eval_v1_dev.yaml;
REMOVE @AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE/eval_v2_dev.yaml;
REMOVE @AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE/eval_v1_holdout.yaml;
REMOVE @AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE/eval_v2_holdout.yaml;

-- 3. Re-copy from the branch holding the fix.
--    Change dev/dcm -> main once the branch is merged.
COPY FILES INTO @AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE
    FROM @AI_AGENT_HOL_DB.DATA.CORTEX_AGENT_QUICKSTART_REPO/branches/dev/dcm/dcm_project/files/evals/
    FILES = ('eval_v1_dev.yaml',
             'eval_v2_dev.yaml',
             'eval_v1_holdout.yaml',
             'eval_v2_holdout.yaml');
ALTER STAGE AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE REFRESH;

-- 4. Verify: expect campaign_groundedness / campaign_execution_efficiency,
--    and NO bare "groundedness" or "execution_efficiency".
SELECT t.$1 AS line
FROM @AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE/eval_v1_dev.yaml t
WHERE t.$1 ILIKE '%- name:%';
