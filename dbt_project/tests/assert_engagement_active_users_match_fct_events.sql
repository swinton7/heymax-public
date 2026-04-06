/*
  assert_engagement_active_users_match_fct_events

  Validates that active_users in rpt_engagement (event_type = 'all')
  matches the count of distinct active users in fct_events for each month.

  Any row returned = test failure.
*/

with eng as (
    select
        month,
        active_users as eng_active
    from {{ ref('rpt_engagement') }}
    where event_type = 'all'
),

fct as (
    select
        date_trunc('month', event_date)::date as month,
        count(distinct user_id)               as fct_active
    from {{ ref('fct_events') }}
    group by 1
)

select
    eng.month,
    eng.eng_active,
    fct.fct_active,
    eng.eng_active - fct.fct_active as diff
from eng
join fct using (month)
where eng.eng_active != fct.fct_active
