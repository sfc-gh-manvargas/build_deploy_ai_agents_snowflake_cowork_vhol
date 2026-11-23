-- Database, schemas, warehouse, integration, file format, stages
--

DEFINE DATABASE {{db}}
    COMMENT = 'Marketing campaigns analytics HOL (managed by DCM project AI_AGENT_HOL)';

DEFINE SCHEMA {{db}}.DATA
    COMMENT = 'Raw campaign tables, eval inputs, file format and git repo';

DEFINE SCHEMA {{db}}.ANALYTICS
    COMMENT = 'Semantic view and Cortex Search service';

DEFINE SCHEMA {{db}}.AGENTS
    COMMENT = 'Cortex Agent, agent skills and evaluation assets';

DEFINE WAREHOUSE {{wh}}
WITH
    WAREHOUSE_SIZE = '{{wh_size}}'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for the AI agent HOL';

-- Git API integration GIT_API_INTEGRATION_AI_AGENT_HOL is created in pre_deploy.sql
-- (needed before the Workspace exists; DEFINE API INTEGRATION not enabled on this account).
-- The git repository object itself is created in post_deploy.sql.

DEFINE FILE FORMAT {{db}}.DATA.AGENT_EVAL_QUICKSTART_CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    COMPRESSION = 'AUTO';

DEFINE STAGE {{db}}.AGENTS.AGENT_SKILLS
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Internal stage hosting Cortex Agent skills';

DEFINE STAGE {{db}}.AGENTS.EVAL_CONFIG_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Internal stage to host evaluation config files';
