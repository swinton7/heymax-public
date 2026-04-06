{{ config(materialized='table') }}

/*
  rpt_growth_accounting — growth accounting cohort classification per period.

  Grain: (period_grain, period_start, cohort_type, country, acquisition_source, first_platform)

  Builds from two sources:
    - int_user_activity_periods : complex cohort spine (who was active when)
    - dim_users                 : dimensional attributes for segmentation

  cohort_type definitions:
    new         — first active period ever for this user
    retained    — active in current period AND immediately prior period
    resurrected — active now, NOT active last period, but seen before
    churned     — active last period, NOT active this period (attributed to the missed period)

  Uses LAG/LEAD window functions over the activity spine — no self-joins.
*/

with activity as (
    select
        user_id,
        period_grain,
        period_start,
        prior_period_start,
        next_period_start
    from {{ ref('int_user_activity_periods') }}
),

users as (
    select
        user_id,
        country,
        acquisition_source,
        first_platform
    from {{ ref('dim_users') }}
),

windowed as (
    select
        user_id,
        period_grain,
        period_start,
        prior_period_start,
        next_period_start,

        lag(period_start) over (
            partition by user_id, period_grain
            order by period_start
        )                                   as lag_period_start,

        lead(period_start) over (
            partition by user_id, period_grain
            order by period_start
        )                                   as lead_period_start,

        min(period_start) over (
            partition by user_id, period_grain
        )                                   as first_period_start

    from activity
),

classified as (
    -- active users: new / retained / resurrected
    select
        user_id,
        period_grain,
        period_start,
        case
            when period_start = first_period_start          then 'new'
            when lag_period_start = prior_period_start      then 'retained'
            else                                                 'resurrected'
        end                                 as cohort_type

    from windowed

    union all

    -- churned: active in period N, missed period N+1
    -- attributed to next_period_start (the period they missed)
    select
        user_id,
        period_grain,
        next_period_start                   as period_start,
        'churned'                           as cohort_type

    from windowed
    where
        lead_period_start is null
        or lead_period_start != next_period_start
)

select
    c.period_grain,
    c.period_start,
    c.cohort_type,
    u.country,
    u.acquisition_source,
    u.first_platform,
    count(distinct c.user_id)               as user_count

from classified c
inner join users u using (user_id)
group by 1, 2, 3, 4, 5, 6
order by 1, 2, 3, 4, 5, 6
