USE ROLE ACCOUNTADMIN;
-- If you set AI_AGENT_HOL_ROLE as your default role, reset it before dropping the role.
-- Replace <your_previous_role> with the role you used before this guide.
SET MY_USER = CURRENT_USER();
ALTER USER IDENTIFIER($MY_USER) SET DEFAULT_ROLE = <your_previous_role>;

DROP DCM PROJECT IF EXISTS AI_AGENT_HOL_ADMIN.DCM.AI_AGENT_HOL;
DROP DATABASE IF EXISTS AI_AGENT_HOL_DB;
DROP DATABASE IF EXISTS AI_AGENT_HOL_ADMIN;
DROP WAREHOUSE IF EXISTS AI_AGENT_HOL_WH;
DROP API INTEGRATION IF EXISTS GIT_API_INTEGRATION_AI_AGENT_HOL;
DROP ROLE IF EXISTS AI_AGENT_HOL_ROLE;

-- Web search is an ACCOUNT-WIDE setting. Uncomment ONLY if it was not enabled
-- before this guide and nothing else in the account relies on it.
-- ALTER ACCOUNT UNSET ENABLE_CORTEX_WEBSEARCH;
