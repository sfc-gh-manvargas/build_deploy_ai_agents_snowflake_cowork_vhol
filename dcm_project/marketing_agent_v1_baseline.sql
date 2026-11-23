-- ====================================================================
-- marketing_agent_v1_baseline.sql - original baseline setup of the Cortex Agent
-- AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT (VERSION$1, alias BASELINE, empty instructions)
-- plus the DEV baseline eval run. DCM has no DEFINE AGENT, so this is a companion script.
-- Run order: pre_deploy.sql -> snow dcm deploy -> post_deploy.sql -> this script.
-- Re-runnable: the agent is only created if missing.
-- ====================================================================

USE ROLE AI_AGENT_HOL_ROLE;
USE WAREHOUSE AI_AGENT_HOL_WH;

-- --------------------------------------------------------------------
-- 1. Baseline agent (VERSION$1, alias BASELINE) + DEV baseline eval
-- --------------------------------------------------------------------
-- IF NOT EXISTS: re-deploying keeps VERSION$2+ committed during the lab.
-- To reset to the baseline, DROP AGENT AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT and re-deploy.
CREATE AGENT IF NOT EXISTS AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT
WITH PROFILE='{ "display_name": "MARKETING_AGENT" }'
    COMMENT=$$ Agent specializing in analyzing marketing campaigns for performance, ROI, feedback, etc. $$
FROM SPECIFICATION $$
{
    "models": {"orchestration": "claude-sonnet-5"},
    "instructions": {
        "orchestration": "",
        "response": "",
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

ALTER AGENT AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT
  MODIFY VERSION VERSION$1 SET ALIAS = baseline;

USE ROLE ACCOUNTADMIN;
GRANT MONITOR ON AGENT AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT TO ROLE ACCOUNTADMIN;
USE ROLE AI_AGENT_HOL_ROLE;

USE SCHEMA AI_AGENT_HOL_DB.AGENTS;
CALL EXECUTE_AI_EVALUATION(
  'START',
  OBJECT_CONSTRUCT('run_name', 'MARKETING_AGENT_V1_DEV_R01'),
  '@AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE/eval_v1_dev.yaml'
);
