/*
  assert_cohort_retention_m0_is_100_pct

  Every cohort must have 100% retention at months_since_first = 0.
  A user's acquisition month is defined as the month they were first active,
  so by definition every user in the cohort was active in that month.

  Any row returned = test failure.
*/

select
    cohort_month,
    months_since_first,
    retention_pct
from {{ ref('rpt_cohort_retention') }}
where months_since_first = 0
  and retention_pct != 100.0
