{{ config(materialized='table') }}

/*
  rpt_net_growth — monthly net user growth.

  net_growth = new + resurrected - churned
  Built from rpt_growth_accounting (monthly grain only).
*/

with monthly as (
    select
        period_start,
        cohort_type,
        sum(user_count) as user_count
    from {{ ref('rpt_growth_accounting') }}
    where period_grain = 'month'
    group by period_start, cohort_type
)

select
    period_start,
    sum(case cohort_type
        when 'new'         then  user_count
        when 'resurrected' then  user_count
        when 'churned'     then -user_count
        else 0
    end)                    as net_growth,
    sum(case when cohort_type = 'new'         then user_count else 0 end) as new_users,
    sum(case when cohort_type = 'retained'    then user_count else 0 end) as retained_users,
    sum(case when cohort_type = 'resurrected' then user_count else 0 end) as resurrected_users,
    sum(case when cohort_type = 'churned'     then user_count else 0 end) as churned_users
from monthly
group by period_start
order by period_start
