# Agent Rules

## Persist all SQL to the repo

- Every SQL statement CoCo runs against Snowflake (DDL, DML, grants, queries, setup scripts) must also be saved to the repo as a `.sql` file, or a similar file (`.sql` inside a notebook, `.yaml` for semantic views/agents) when SQL isn't the right format.
- Do this without being asked, in the same turn the SQL is run. Don't leave SQL only in chat or tool calls.
- Save the full statement, including complete function, procedure, and agent bodies. Don't save only a reference or a `CREATE ... FROM` pointer.
- Organize by purpose in numbered, ordered files so they can be re-run top to bottom (e.g. `sql/01_setup.sql`, `sql/02_tables.sql`, `sql/03_agent.sql`).
- Update the existing file for a step instead of creating duplicates. Keep scripts idempotent where possible (`CREATE OR REPLACE`, `IF NOT EXISTS`).
- Ad-hoc exploratory queries go in `sql/scratch/` or are appended to a clearly named file.
