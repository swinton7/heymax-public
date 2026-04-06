{{ config(materialized='table') }}

/*
  rpt_cohort_retention — monthly cohort retention triangle.

  For each acquisition cohort (month of first_seen_at), tracks what
  percentage of users were still active N months later.

  Grain: (cohort_month, months_since_first)
  Builds from dim_users (cohort definition) + int_user_activity_periods (activity).
*/

with cohort_activity as (
    select
        date_trunc('month', u.first_seen_at)::date      as cohort_month,
        a.period_start,
        datediff('month',
            date_trunc('month', u.first_seen_at)::date,
            a.period_start
        )                                               as months_since_first,
        count(distinct u.user_id)                       as retained_users
    from {{ ref('dim_users') }} u
    join {{ ref('int_user_activity_periods') }} a
        on  u.user_id     = a.user_id
        and a.period_grain = 'month'
    group by 1, 2, 3
),

cohort_sizes as (
    select
        date_trunc('month', first_seen_at)::date    as cohort_month,
        count(*)                                    as cohort_size
    from {{ ref('dim_users') }}
    group by 1
)

select
    r.cohort_month,
    r.months_since_first,
    r.retained_users,
    s.cohort_size,
    round(r.retained_users * 100.0 / s.cohort_size, 1) as retention_pct
from cohort_activity r
join cohort_sizes s using (cohort_month)
order by 1, 2
