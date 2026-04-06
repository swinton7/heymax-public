# Reflection Questions

## 1. When would you NOT use an AI agent for a data task?

When the correctness of the output depends on a business decision that hasn't been made yet — not a technical one.

A concrete example from Part 1: the churn attribution logic in `rpt_growth_accounting`. The question was whether a churned user should be attributed to the last period they were active, or to the first period they missed. Both are defensible. The first feels natural; the second is what most growth accounting frameworks use because it makes the waterfall chart balance.

An AI agent could generate either interpretation confidently and coherently. It could even cite a reasonable source for whichever it picked. But this isn't a documentation task or a pattern-matching task — it's a decision about how the business wants to measure user loss. Getting it wrong means every downstream cohort count, every "we grew by X users this month" report, is built on a quietly wrong foundation.

The rule I use: if the correct answer requires someone with business context to make a call — not just someone with SQL skills — don't delegate it to an agent. Use the agent for the work that follows once the decision is made.

---

## 2. How do you evaluate the quality of LLM-generated outputs in a data context?

A good eval is grounded in something that doesn't change when you change the model: known-correct outputs, structural invariants, or human judgment on a fixed sample.

For the documentation agent specifically, a good eval would look like:

- **Ground truth set**: take 20 columns from existing, well-documented models where you're confident the descriptions are correct. Strip the descriptions, run the agent, measure how many it gets right — and define "right" with a rubric before you look at the outputs, not after.
- **Structural checks**: does the proposed description contain aggregation language on a non-aggregated column? Does it mention a column name that doesn't exist in the schema? These are automatable and catch a class of failures before a human ever sees the output.
- **Consistency test**: run the same model through the agent twice with slightly different prompt phrasing. If the descriptions diverge materially, the agent is more sensitive to prompt wording than to the SQL — which means it's pattern-matching on language, not reasoning about the model.

A bad eval is: "I read through a few outputs and they looked reasonable." That's a vibe check, not an eval. It finds embarrassing failures but misses the subtle, confident ones — which are the ones that cause real harm in a data context.

---

## 3. If the documentation agent shipped and started producing subtly wrong descriptions at scale, how would you catch it?

The word "subtly" is the hard part. Obvious failures get caught in review. Subtle ones pass review because they look plausible to someone who doesn't know the data deeply.

Three things I'd put in place:

**Canary models with locked ground truth.** Pick five or six models that meet three criteria: in production for at least three months, have a documented business owner, and had descriptions written by a human with domain knowledge (not the agent). These are the models where you can verify correctness without needing to re-derive business meaning. Store the correct descriptions separately. On every agent run, regenerate docs for these canary models and diff against the ground truth. Any divergence is a signal the prompt or model behaviour has drifted.

**Linting for semantic red flags.** Build a small rule set: fact table columns shouldn't have descriptions with `total`, `sum of`, or `lifetime`; dimension columns shouldn't reference event counts; `_id` columns should always say "identifier" or "key." These are cheap to check and catch a specific class of hallucination — the kind where the agent describes what a column aggregates to rather than what a single row of it contains.

**Periodic human audit, not just at merge time.** Reviews at PR time are biased toward approval — the engineer is in a flow state and the docs are one part of a larger change. A quarterly sample review, where someone sits down with 30 random agent-generated descriptions and no other context, catches a different category of subtle error. The question isn't "does this look reasonable?" but "is this actually correct for how we use this column?"

---

## 4. What is one AI-native capability you wish existed in the modern data stack today?

**Metric change attribution that reasons across the transformation graph, not just shows it.**

Every data team has a version of this experience: a key metric moves unexpectedly, you open the DAG, you can see the lineage — but the DAG just shows you the graph. It doesn't tell you *why* the number changed or *where* in the pipeline the change originated. You end up manually bisecting: checking row counts at each layer, eyeballing distributions, ruling out sources one by one.

What I'd want is an agent that can answer the question "why did `net_growth` drop 18% this month?" by reasoning across the transformation graph autonomously: pulling row counts and distributions at each layer, comparing them against prior runs, forming and testing hypotheses ("resurrected users declined — is that a data issue or real?"), and returning a ranked list of likely root causes with supporting evidence.

The data to answer that question already exists in the warehouse. The DAG already encodes the relationships. What's missing is the reasoning layer that connects them to a natural-language question. Every other part of the stack has matured significantly; root-cause investigation is still largely manual, and it's one of the highest-leverage places where an AI-native tool could return real time to engineers.
