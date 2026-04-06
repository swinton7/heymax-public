{{ config(materialized='table') }}

/*
  One row per (user_id, period_grain, period_start) where the user had at least one event.
  Built from fct_events (marts layer) — sits between marts and reports.
  Feeds into rpt_growth_accounting for New/Retained/Resurrected/Churned classification.

  period_grain     : 'day' | 'week' | 'month'
  period_start     : truncated date for that grain (Monday for weeks, 1st for months)
  prior_period_start: the immediately preceding period start date for this grain
  next_period_start : the immediately following period start date for this grain

  Offset arithmetic is owned here so downstream models have no hardcoded intervals.
  To add a new grain (e.g. 'quarter'), only this model needs to change.
*/

with events as (
    select
        user_id,
        event_date
    from {{ ref('fct_events') }}
),

daily as (
    select
        user_id,
        event_date                                          as period_start,
        'day'                                               as period_grain
    from events
    group by user_id, event_date
),

weekly as (
    select
        user_id,
        date_trunc('week', event_date)::date                as period_start,
        'week'                                              as period_grain
    from events
    group by user_id, date_trunc('week', event_date)
),

monthly as (
    select
        user_id,
        date_trunc('month', event_date)::date               as period_start,
        'month'                                             as period_grain
    from events
    group by user_id, date_trunc('month', event_date)
),

combined as (
    select * from daily
    union all
    select * from weekly
    union all
    select * from monthly
)

select
    user_id,
    period_grain,
    period_start,
    case period_grain
        when 'day'   then (period_start - interval '1 day')::date
        when 'week'  then (period_start - interval '7 days')::date
        when 'month' then (period_start - interval '1 month')::date
    end                                                     as prior_period_start,
    case period_grain
        when 'day'   then (period_start + interval '1 day')::date
        when 'week'  then (period_start + interval '7 days')::date
        when 'month' then (period_start + interval '1 month')::date
    end                                                     as next_period_start

from combined
