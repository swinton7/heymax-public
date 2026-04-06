/*
  assert_cohort_size_matches_dim_users

  Validates that the cohort_size in rpt_cohort_retention matches the
  actual count of users in dim_users acquired in that cohort month.

  cohort_month is derived from first_seen_at in dim_users, so these
  two counts must always agree.

  Any row returned = test failure.
*/

with dim_cohorts as (
    select
        date_trunc('month', first_seen_at)::date as cohort_month,
        count(*)                                 as dim_size
    from {{ ref('dim_users') }}
    group by 1
),

rpt_cohorts as (
    select
        cohort_month,
        max(cohort_size) as rpt_size
    from {{ ref('rpt_cohort_retention') }}
    group by 1
)

select
    d.cohort_month,
    d.dim_size,
    r.rpt_size,
    d.dim_size - r.rpt_size as diff
from dim_cohorts d
join rpt_cohorts r using (cohort_month)
where d.dim_size != r.rpt_size
