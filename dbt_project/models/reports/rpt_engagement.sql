{{ config(materialized='table') }}

/*
  rpt_engagement — monthly engagement depth metrics.

  Two complementary views of engagement:
    - events_per_user: how intensely active users engage each month
    - event_type_mix : breakdown of what users are doing each month

  Grain: (month, event_type) — event_type = 'all' for the top-level summary row.
  Builds from fct_events.
*/

with monthly_summary as (
    select
        date_trunc('month', event_date)::date           as month,
        'all'                                           as event_type,
        count(*)                                        as total_events,
        count(distinct user_id)                         as active_users,
        round(count(*) / count(distinct user_id)::double, 2) as events_per_user
    from {{ ref('fct_events') }}
    group by 1
),

monthly_by_type as (
    select
        date_trunc('month', event_date)::date           as month,
        event_type,
        count(*)                                        as total_events,
        count(distinct user_id)                         as active_users,
        round(count(*) / count(distinct user_id)::double, 2) as events_per_user
    from {{ ref('fct_events') }}
    group by 1, 2
)

select * from monthly_summary
union all
select * from monthly_by_type
order by month, event_type
