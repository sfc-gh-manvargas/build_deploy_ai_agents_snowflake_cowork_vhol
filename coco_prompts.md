# Improve Your Agent with CoCo

Open **CoCo** in Snowsight with role **AI_AGENT_HOL_ROLE**, then paste each prompt in order.
Tip: when CoCo asks `Run this command?`, choose **Always allow**.

| Prompt | What happens | Eval run |
|---|---|---|
| 1 | CoCo reads the baseline results and creates `VERSION$2` | - |
| 2 | Score `VERSION$2` on the development questions | `MARKETING_AGENT_V2_DEV_R01` |
| 3 | Score both versions on the held-out questions and decide | `MARKETING_AGENT_V1/V2_HOLDOUT_R01` |

> **Run every evaluation as `AI_AGENT_HOL_ROLE`.** The eval calls the agent with the session's primary role only; secondary roles are not used. `AI_AGENT_HOL_ROLE` owns the agent, while `ACCOUNTADMIN` only has `MONITOR`. Starting a run as `ACCOUNTADMIN` fails with `401` / `399513` "The agent does not exist or access is not authorized for the current role", and the run name is then used up. Switching roles in Snowsight does not change the role of an existing CoCo chat, so the prompts below tell CoCo to run `USE ROLE AI_AGENT_HOL_ROLE` itself and check `CURRENT_ROLE()` before `START`. If a run fails anyway, rerun it under a new run name (`..._R02`).

> Tune on the **development** questions. The **held-out** questions are only for the final decision, so don't show them to CoCo before Prompt 3.

---

## Prompt 1: Find failure patterns and fix them

```
Look at eval run MARKETING_AGENT_V1_DEV_R01 for agent AI_AGENT_HOL_DB.AGENTS.MARKETING_AGENT and find common failure patterns.
Do not look at the held-out dataset or any HOLDOUT runs.
Write improved orchestration and response instructions that fix those patterns: response format, when to use multiple tools and in what order, and efficient tool calling.
Change only the instructions, not the tools.
Commit the change as a new agent version VERSION$2 (never overwrite VERSION$1) and show SHOW VERSIONS before and after.
Use the agent-studio skill.
```

## Prompt 2: Score the new version

```
Start an evaluation with run name MARKETING_AGENT_V2_DEV_R01 using
@AI_AGENT_HOL_DB.AGENTS.EVAL_CONFIG_STAGE/eval_v2_dev.yaml.
Start it as role AI_AGENT_HOL_ROLE: run USE ROLE AI_AGENT_HOL_ROLE in the same SQL call as START, and first confirm SELECT CURRENT_ROLE() returns AI_AGENT_HOL_ROLE. Do not start it as ACCOUNTADMIN.
Poll STATUS until COMPLETED. If it FAILED, show the error and stop; do not reuse the run name.
When it finishes, compare it with MARKETING_AGENT_V1_DEV_R01: scores by metric, and which questions improved, stayed the same, or regressed.
Use the agent-studio skill.
```

## Prompt 3: Does it generalize?

Run this once you're done changing the agent.

```
Run dcm_project/evaluate_holdout.sql as role AI_AGENT_HOL_ROLE (keep its USE ROLE line; confirm CURRENT_ROLE() before START). Do not change the agent.
If MARKETING_AGENT_V2_DEV_R01 has no scores, say so instead of comparing against it.
When both runs finish, compare all four runs: VERSION$1 vs VERSION$2, on development and held-out questions.
Recommend whether to promote VERSION$2 based on the held-out results, and say what 5 held-out questions can't prove.
```

---

## Your turn (optional)

Try another improvement, for example better tool descriptions or a different orchestration model.
Commit each change as the next version (`VERSION$3`, ...) and ask CoCo to evaluate it on the development questions with a new run name (`MARKETING_AGENT_V3_DEV_R01`), using a copy of `eval_v2_dev.yaml` saved as `eval_v3_dev.yaml` with the new version. As in Prompt 2, tell CoCo to start the run as `AI_AGENT_HOL_ROLE`.
