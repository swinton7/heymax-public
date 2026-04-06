# Data Documentation Agent — Design Doc

## Overview

The agent generates and maintains column-level dbt documentation (`schema.yml` entries) as models evolve. Documentation is one of the most consistently neglected parts of an analytics codebase — not because engineers don't value it, but because writing it is slow, repetitive, and disconnected from the work that creates value. This is a good fit for LLM automation: the output is text a human can review before it lands, the inputs are structured (SQL + manifest), and "good enough" is genuinely useful even if not perfect.

---

## A. Agent Architecture

### Trigger

The agent runs in CI on any pull request that modifies a `.sql` file under `models/`. It does not run on every commit — only when model definitions change, keeping cost and noise low.

### Inputs

For each modified model the agent receives:

1. The model's SQL source file (raw, pre-Jinja)
2. The compiled SQL from `dbt compile` — so the agent sees actual column expressions, not macro calls
3. The current `schema.yml` block for this model (if one exists)
4. Upstream column descriptions from the dbt manifest — descriptions already approved for `ref()`d models feed forward as context

### Tool call sequence

```
1. parse_manifest(model_name)
   → columns, upstream_models, materialization, tags

2. read_sql(model_path)
   → raw SQL + compiled SQL

3. read_schema(model_name)
   → existing schema.yml block, or null if new model

4. call_llm(prompt)
   → inputs : compiled SQL, upstream descriptions, existing docs
   → output : proposed schema.yml block (YAML, column descriptions only)

5. post_pr_comment(diff)
   → side-by-side diff of existing vs. proposed — never writes to disk directly
```

The agent never commits to `schema.yml`. It posts a diff and waits for a human.

### New vs. existing models

- **New model** — generates from scratch with no existing description baseline to diff against. All columns are tagged `[DRAFT]` unconditionally, and a CI lint check blocks the PR from merging until a human removes each tag.
- **Existing model** — diffs compiled SQL against the current docs. Only columns whose expressions changed get re-proposed. Columns with an approved description and no SQL change are never touched — the agent does not regenerate descriptions that are already good. This preserves human edits, prevents description degradation over time, and keeps PR comments short.

---

## B. Human-in-the-Loop Design

**Review gate** — Every proposal surfaces as a PR comment structured in three sections: *unchanged* (collapsed by default), *updated* (highlighted), and *new* (highlighted). An engineer approves, edits inline, or dismisses before anything reaches `schema.yml`. The agent never auto-merges.

**Surfacing changes** — The diff format makes it fast to review: engineers see exactly what changed and why (the column expression that triggered the update is shown alongside the proposed description).

**Preventing silent bad docs** — Two controls work in combination:
1. Beyond new models, `[DRAFT]` is also applied to any column where upstream lineage in the manifest is empty — meaning the agent had no approved context to draw from. `[DRAFT]` columns are blocked from merging by a CI lint check until a human removes the tag.
2. A nightly job compares `schema.yml` column lists against the current `manifest.json`. Any column present in the manifest but absent or stale in the schema (not updated in 30+ days while the model changed) raises an alert — catching drift even when the agent wasn't triggered.

---

## C. Failure Modes & Observability

**1. Confident hallucination — plausible but wrong description**

Example: `miles_amount` described as "total lifetime miles earned by the user" when it is actually "miles for this single event." Grammatically correct, passes a quick skim, quietly poisons downstream analysis.

*Detection*: human review is the primary control. Secondary: automated linter flags descriptions containing aggregation language (`total`, `sum of`, `lifetime`, `cumulative`) on staging and fact table columns — a grain-level row like `miles_amount` in `fct_events` should never be described as a total or lifetime value. False positives are possible but rare enough to route to mandatory review rather than auto-reject.

*Alerting*: any description matching the aggregation pattern on a `fct_` or `stg_` model is blocked and routed to mandatory human review.

**2. Silent staleness — upstream changes don't propagate**

The agent triggers on direct SQL changes. But a column's meaning can shift through upstream model changes even when its own file is untouched. If `stg_events.utm_source` gains a new accepted value, the description in `dim_users` becomes incomplete — and the agent was never triggered.

*Detection*: on every dbt run, store a hash of each model's compiled column list. Flag models where the hash changed but docs haven't been touched in 30+ days.

*Alerting*: weekly digest of models with stale documentation scores, sent to the owning team in Slack.

**3. Over-triggering — noise kills adoption**

If the agent comments on every minor SQL reformatting, engineers start dismissing it reflexively. Low signal-to-noise destroys adoption faster than bad docs.

*Detection*: track the engineer acceptance rate per run (proposals merged without edit). Below 40%, the agent is generating more noise than value and the trigger or prompt needs tightening.

*Alerting*: weekly review of dismissal rates. Auto-pause the agent if acceptance falls below 30% for two consecutive weeks — at that point, engineers will start ignoring PR comments entirely, which is worse than no agent at all.

---

## D. Scope & Build Plan

### v1 — one week

**In scope**
- CI trigger on PR for changed `.sql` files
- Single-model context only — no cross-model lineage traversal in the prompt. Each additional upstream model in context adds ~$0.02–0.05 in tokens and 1–3 s of latency; traversing a 50-model DAG would exceed $1 per run and 60 s — not viable as a PR gate in v1.
- Generate and diff column descriptions, post as PR comment
- Engineer approves or edits before merge
- Basic logging: model name, columns proposed vs. accepted, latency, token cost per run

**Out of scope**
- Auto-commit to `schema.yml` (never in v1 — trust must be earned first)
- Cross-model lineage context in the prompt (v2)
- Batch backfill of undocumented models — defined as any model with no `schema.yml` entry, or with fewer documented columns than `manifest.json` lists (v2)
- Custom eval harness (v2 — v1 uses human acceptance rate as the proxy)

### Success metrics

| Metric | Target |
|---|---|
| **Coverage** — % of dbt columns with an approved, non-`[DRAFT]` description | 80% within 60 days |
| **Acceptance rate** — % of proposals merged without human edit | ≥ 60% |
| **Time-to-docs** — median time from model creation to first approved description | < 24 h (same PR cycle) |
| **Cost per run** — LLM tokens per model | < $0.10 to stay viable at scale |

The acceptance rate is the most important signal. High coverage with low acceptance means engineers are rubber-stamping — which is a documentation quality risk dressed up as a success metric.
