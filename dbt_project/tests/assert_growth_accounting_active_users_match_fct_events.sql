/*
  assert_growth_accounting_active_users_match_fct_events

  Validates that the sum of new + retained + resurrected users in
  rpt_growth_accounting (monthly grain) exactly matches the count of
  distinct active users in fct_events for each month.

  Any row returned = test failure.
*/

with ga_active as (
    select
        period_start,
        sum(user_count) as ga_active_users
    from {{ ref('rpt_growth_accounting') }}
    where period_grain = 'month'
      and cohort_type in ('new', 'retained', 'resurrected')
    group by period_start
),

fct_active as (
    select
        date_trunc('month', event_date)::date as period_start,
        count(distinct user_id)               as fct_active_users
    from {{ ref('fct_events') }}
    group by 1
)

select
    ga.period_start,
    ga.ga_active_users,
    fct.fct_active_users,
    ga.ga_active_users - fct.fct_active_users as diff
from ga_active ga
join fct_active fct using (period_start)
where ga.ga_active_users != fct.fct_active_users
