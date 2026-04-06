# HeyMax — Growth Accounting Analytics Stack

End-to-end analytics pipeline for the HeyMax Senior Analytics Engineer take-home assessment.

**Stack:** DuckDB · dbt · Plotly · Jupyter · GitHub Actions · Docker

---

## What This Builds

A local analytics warehouse over a CSV of user events (Feb – Nov 2025) with a fully interactive growth accounting dashboard.

| Deliverable | Description |
|---|---|
| `heymax.duckdb` | Local DuckDB warehouse populated by dbt |
| `dim_users` | One row per user — stable descriptive attributes |
| `fct_events` | One row per event — FK to `dim_users` |
| `int_user_activity_periods` | Activity spine across daily / weekly / monthly grains |
| `rpt_growth_accounting` | New / Retained / Resurrected / Churned per period + dimensions |
| `rpt_net_growth` | Monthly net user growth (new + resurrected − churned) |
| `rpt_cohort_retention` | Cohort retention triangle (% still active N months later) |
| `rpt_engagement` | Events-per-user and event type mix by month |
| `rpt_miles_economy` | Miles earned vs redeemed + top categories |
| `dashboard/growth_accounting.html` | Self-contained Plotly dashboard, no server required |

---

## Prerequisites

- Python 3.11+
- `pip`
- `make`
- `unzip`

No database server, no cloud account, no Node.js.

---

## Quick Start (Local)

```bash
# 1. Clone the repo
git clone <repo-url>
cd heymax-demo

# 2. Install Python dependencies
make install

# 3. Run the full pipeline (extract → transform → test → dashboard)
make all
```

Open `dashboard/growth_accounting.html` in any browser when done.

---

## Step-by-Step

Each `make` target can be run independently:

```bash
make install      # pip install -r requirements.txt

make extract      # unzip event_stream.csv.zip → data/

make transform    # dbt deps + dbt run  (builds all 9 models into heymax.duckdb)

make test         # dbt test  (74 data quality tests)

make dashboard    # regenerate notebook + export to HTML

make docs         # dbt docs generate + serve  (localhost:8080)

make clean        # remove heymax.duckdb, data/, dbt artifacts
```

---

## Docker

Run the complete pipeline in an isolated container:

```bash
docker build -t heymax-demo .

docker run --rm \
  -v "$(pwd)/dbt_project:/app/dbt_project" \
  -v "$(pwd)/dashboard:/app/dashboard" \
  heymax-demo
```

- `event_stream.csv.zip` is copied into the image at build time — it must exist in the project root.
- `dbt_project/` is mounted so the container uses your local models and profile — models and config are not baked into the image.
- `dashboard/` is mounted so the generated HTML appears on your host after the container exits.
- `dbt deps` runs as part of `make transform` — packages are installed fresh each run from `packages.yml`.

---

## Project Structure

```
heymax-demo/
├── data/                        # CSV data (gitignored — recreated by make extract)
│   └── event_stream.csv
├── dbt_project/
│   ├── models/
│   │   ├── staging/             # stg_events — typed, cleaned, incremental
│   │   ├── intermediate/        # int_user_activity_periods — activity spine
│   │   ├── marts/               # dim_users, fct_events — Kimball core
│   │   └── reports/             # rpt_* — pre-built report tables
│   ├── tests/                   # custom dbt singular tests
│   ├── profiles.yml             # DuckDB connection (local file)
│   ├── dbt_project.yml
│   └── packages.yml             # dbt_utils
├── dashboard/
│   ├── build_notebook.py        # generates growth_accounting.ipynb programmatically
│   ├── growth_accounting.ipynb  # executed notebook
│   └── growth_accounting.html   # self-contained export (open in browser)
├── .github/
│   └── workflows/
│       └── ci.yml               # dbt run + dbt test on push/PR
├── agent-design.md              # Part 2: AI Documentation Agent design
├── REFLECTION.md                # 4 reflection questions
├── Dockerfile
├── Makefile
├── requirements.txt
└── README.md
```

---

## Data Model

```
stg_events  (incremental)
    │
    ├──▶  dim_users  (table)          ← stable user attributes
    │
    ├──▶  fct_events  (table)         ← one row per event
    │         │
    │         └──▶  int_user_activity_periods  (table)
    │                       │
    │                       ├──▶  rpt_growth_accounting
    │                       │           └──▶  rpt_net_growth
    │                       └──▶  rpt_cohort_retention
    │
    └──▶  rpt_engagement
          rpt_miles_economy
```

`stg_events` reads directly from `data/event_stream.csv` via DuckDB `read_csv_auto` — no ingestion script.

---

## Growth Accounting Definitions

| Cohort | Definition |
|---|---|
| **New** | First active period ever |
| **Retained** | Active in current period AND the immediately prior period |
| **Resurrected** | Active now, not last period, but seen before |
| **Churned** | Active last period, absent this period — attributed to the missed period |

Computed using LAG/LEAD window functions over the activity spine. Available at daily, weekly, and monthly grains.

---

## CI/CD

GitHub Actions runs on every push and pull request to `main`:

1. Install dependencies
2. `make transform` — run all dbt models
3. `make test` — 74 dbt data quality tests

To supply the CSV in CI, add a data download step in `.github/workflows/ci.yml` (e.g. from an S3 bucket or a GitHub release asset).

---

## Production Upgrade Path

The stack is intentionally minimal for local development. Production equivalents:

| Demo | Production |
|---|---|
| Local CSV via `read_csv_auto` | S3 + DuckDB `httpfs` — same dbt model, just swap the path |
| Local DuckDB file | [MotherDuck](https://motherduck.com) — managed DuckDB, no other changes |
| GitHub Actions cron | Airflow / Prefect — swap orchestrator, dbt models unchanged |
| Static HTML | Metabase / Lightdash connected to DuckDB / MotherDuck |
| Long-lived secrets | GitHub OIDC → short-lived IAM credentials, no stored keys |
