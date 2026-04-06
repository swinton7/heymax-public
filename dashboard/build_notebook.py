"""
Generates growth_accounting.ipynb programmatically via nbformat.
Run: python dashboard/build_notebook.py
"""
import nbformat as nbf
from pathlib import Path

nb = nbf.v4.new_notebook()
nb.metadata = {
    "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
    "language_info": {"name": "python", "version": "3.9.0"},
}

cells = []

def md(src): return nbf.v4.new_markdown_cell(src)
def code(src): return nbf.v4.new_code_cell(src)

# ── Title ────────────────────────────────────────────────────────────────────
cells.append(md("""# HeyMax — Growth Accounting Dashboard
Analytics stack: DuckDB + dbt · Data: `event_stream.csv` (Feb – Nov 2025)
"""))

# ── Setup ────────────────────────────────────────────────────────────────────
cells.append(code("""\
import pathlib
import duckdb, pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
from IPython.display import display, HTML

DB_PATH = str(pathlib.Path("../heymax.duckdb").resolve())
con = duckdb.connect(DB_PATH, read_only=True)

COHORT_COLORS = {
    "new":         "#2ecc71",
    "retained":    "#3498db",
    "resurrected": "#f39c12",
    "churned":     "#e74c3c",
}

def q(sql: str) -> pd.DataFrame:
    return con.execute(sql).df()

_plotlyjs_included = False

def show(fig):
    global _plotlyjs_included
    include_js = "cdn" if not _plotlyjs_included else False
    _plotlyjs_included = True
    display(HTML(fig.to_html(full_html=False, include_plotlyjs=include_js)))

print("Connected ✓")
"""))

# ── 1. Growth Accounting — Monthly ───────────────────────────────────────────
cells.append(md("## 1 · Growth Accounting — Monthly"))
cells.append(code("""\
monthly = q(\"\"\"
    SELECT period_start, cohort_type, sum(user_count) as user_count
    FROM main_reports.rpt_growth_accounting
    WHERE period_grain = 'month'
    GROUP BY 1, 2
    ORDER BY 1, 2
\"\"\")

fig = go.Figure()
for ctype in ["new", "retained", "resurrected"]:
    df = monthly[monthly.cohort_type == ctype]
    fig.add_trace(go.Bar(
        x=df.period_start, y=df.user_count,
        name=ctype.capitalize(), marker_color=COHORT_COLORS[ctype],
    ))
churned = monthly[monthly.cohort_type == "churned"]
fig.add_trace(go.Bar(
    x=churned.period_start, y=-churned.user_count,
    name="Churned", marker_color=COHORT_COLORS["churned"],
))
fig.add_hline(y=0, line_width=1, line_color="black")
fig.update_layout(
    title="Monthly Growth Accounting — Active Users by Cohort",
    barmode="relative",
    xaxis_title="Month", yaxis_title="Users (churned shown as negative)",
    legend_title="Cohort", height=450, template="plotly_white",
)
show(fig)
"""))

# ── 2. Growth Accounting — Weekly ────────────────────────────────────────────
cells.append(md("## 2 · Growth Accounting — Weekly"))
cells.append(code("""\
weekly = q(\"\"\"
    SELECT period_start, cohort_type, sum(user_count) as user_count
    FROM main_reports.rpt_growth_accounting
    WHERE period_grain = 'week'
    GROUP BY 1, 2
    ORDER BY 1, 2
\"\"\")

fig = go.Figure()
for ctype in ["new", "retained", "resurrected"]:
    df = weekly[weekly.cohort_type == ctype]
    fig.add_trace(go.Bar(
        x=df.period_start, y=df.user_count,
        name=ctype.capitalize(), marker_color=COHORT_COLORS[ctype],
    ))
churned_w = weekly[weekly.cohort_type == "churned"]
fig.add_trace(go.Bar(
    x=churned_w.period_start, y=-churned_w.user_count,
    name="Churned", marker_color=COHORT_COLORS["churned"],
))
fig.add_hline(y=0, line_width=1, line_color="black")
fig.update_layout(
    title="Weekly Growth Accounting — Active Users by Cohort",
    barmode="relative",
    xaxis_title="Week", yaxis_title="Users (churned shown as negative)",
    legend_title="Cohort", height=450, template="plotly_white",
)
show(fig)
"""))

# ── 3. Net User Growth ────────────────────────────────────────────────────────
cells.append(md("## 3 · Net User Growth (Monthly)\n> `net = new + resurrected − churned`"))
cells.append(code("""\
net = q("SELECT * FROM main_reports.rpt_net_growth ORDER BY period_start")

fig = go.Figure()
fig.add_trace(go.Bar(
    x=net.period_start,
    y=net.net_growth,
    marker_color=[COHORT_COLORS["new"] if v >= 0 else COHORT_COLORS["churned"]
                  for v in net.net_growth],
))
fig.add_hline(y=0, line_width=1, line_color="black")
fig.update_layout(
    title="Net Monthly User Growth",
    xaxis_title="Month", yaxis_title="Net Users Added",
    height=380, template="plotly_white",
)
show(fig)
"""))

# ── 4. Cohort Retention Triangle ─────────────────────────────────────────────
cells.append(md("""## 4 · Cohort Retention Triangle (Monthly)
Percentage of users from each acquisition cohort still active N months later.
"""))
cells.append(code("""\
retention = q("SELECT * FROM main_reports.rpt_cohort_retention ORDER BY cohort_month, months_since_first")

pivot = retention.pivot(index="cohort_month", columns="months_since_first", values="retention_pct")
pivot.index = pivot.index.astype(str).str[:7]
pivot.columns = [f"M+{c}" for c in pivot.columns]

fig = px.imshow(
    pivot,
    text_auto=".0f",
    color_continuous_scale="Blues",
    aspect="auto",
    title="Cohort Retention (%) — Months Since First Active",
    labels={"x": "Months Since Acquisition", "y": "Cohort Month", "color": "Retention %"},
)
fig.update_coloraxes(colorbar_ticksuffix="%")
fig.update_layout(height=500, template="plotly_white")
show(fig)
"""))

# ── 5. Engagement Depth ───────────────────────────────────────────────────────
cells.append(md("## 5 · Engagement Depth"))
cells.append(code("""\
engagement = q("SELECT * FROM main_reports.rpt_engagement WHERE event_type = 'all' ORDER BY month")
event_mix  = q("SELECT * FROM main_reports.rpt_engagement WHERE event_type != 'all' ORDER BY month, event_type")

fig = make_subplots(
    rows=2, cols=1,
    subplot_titles=("Events per Active User (Monthly)", "Event Type Mix (Monthly)"),
    vertical_spacing=0.15,
)
fig.add_trace(
    go.Scatter(
        x=engagement.month, y=engagement.events_per_user,
        mode="lines+markers", name="Events / User",
        line=dict(color="#3498db", width=2), marker=dict(size=7),
    ),
    row=1, col=1,
)
palette = px.colors.qualitative.Set2
for i, etype in enumerate(event_mix.event_type.unique()):
    d = event_mix[event_mix.event_type == etype]
    fig.add_trace(
        go.Bar(x=d.month, y=d.total_events, name=etype,
               marker_color=palette[i % len(palette)]),
        row=2, col=1,
    )
fig.update_layout(
    height=700, barmode="stack", template="plotly_white",
    title_text="Engagement Depth",
    legend=dict(orientation="h", y=-0.1),
)
show(fig)
"""))

# ── 6. Acquisition Breakdown ──────────────────────────────────────────────────
cells.append(md("## 6 · Acquisition & Audience Breakdown"))
cells.append(code("""\
by_source   = q("SELECT acquisition_source, count(*) AS users FROM main_marts.dim_users GROUP BY 1 ORDER BY 2 DESC")
by_country  = q("SELECT country, count(*) AS users FROM main_marts.dim_users GROUP BY 1 ORDER BY 2 DESC")
by_platform = q("SELECT first_platform AS platform, count(*) AS users FROM main_marts.dim_users GROUP BY 1 ORDER BY 2 DESC")

fig = make_subplots(
    rows=1, cols=3,
    specs=[[{"type": "pie"}, {"type": "pie"}, {"type": "pie"}]],
    subplot_titles=("By Acquisition Source", "By Country", "By First Platform"),
)
fig.add_trace(go.Pie(labels=by_source.acquisition_source, values=by_source.users, hole=0.4), row=1, col=1)
fig.add_trace(go.Pie(labels=by_country.country,           values=by_country.users, hole=0.4), row=1, col=2)
fig.add_trace(go.Pie(labels=by_platform.platform,         values=by_platform.users, hole=0.4), row=1, col=3)
fig.update_layout(height=420, template="plotly_white", title_text="Audience Breakdown")
show(fig)
"""))

# ── 7. Miles Economy ──────────────────────────────────────────────────────────
cells.append(md("""## 7 · Miles Economy
> Bonus insight — earned vs redeemed over time reveals the health of the rewards loop.
"""))
cells.append(code("""\
miles_flow  = q("SELECT * FROM main_reports.rpt_miles_economy WHERE month IS NOT NULL ORDER BY month, event_type")
categories  = q("SELECT * FROM main_reports.rpt_miles_economy WHERE month IS NULL ORDER BY total_miles DESC")

fig = make_subplots(
    rows=1, cols=2,
    subplot_titles=("Miles Earned vs Redeemed (Monthly)", "Top Categories by Miles"),
    column_widths=[0.6, 0.4],
)
for etype, color in [("miles_earned", "#2ecc71"), ("miles_redeemed", "#e74c3c")]:
    d = miles_flow[miles_flow.event_type == etype]
    fig.add_trace(go.Bar(
        x=d.month, y=d.total_miles,
        name=etype.replace("_", " ").title(), marker_color=color,
    ), row=1, col=1)
fig.add_trace(go.Bar(
    x=categories.total_miles, y=categories.transaction_category,
    orientation="h", marker_color="#3498db", showlegend=False,
), row=1, col=2)
fig.update_layout(height=420, barmode="group", template="plotly_white", title_text="Miles Economy")
show(fig)
"""))

# ── 8. Closing ────────────────────────────────────────────────────────────────
cells.append(md("---\n*Generated by HeyMax analytics pipeline · DuckDB + dbt + Plotly*"))
cells.append(code("con.close()"))

nb.cells = cells

out = Path(__file__).parent / "growth_accounting.ipynb"
with open(out, "w") as f:
    nbf.write(nb, f)

print(f"Notebook written → {out}")
