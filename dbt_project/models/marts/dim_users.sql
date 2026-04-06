{{ config(materialized='table') }}

/*
  dim_users — one row per user.

  Contains only stable descriptive attributes — who the user is,
  not what they have done. Attributes are anchored to the user's
  first observed event to prevent historical rewrites.

  Additive metrics (total_events, miles, etc.) belong in fct_user_metrics.
*/

with events as (
    select * from {{ ref('stg_events') }}
),

first_event_attrs as (
    select distinct on (user_id)
        user_id,
        gender,
        country,
        platform        as first_platform,
        utm_source      as acquisition_source,
        event_type      as first_event_type,
        event_time      as first_seen_at
    from events
    order by user_id, event_time
),

last_seen as (
    select
        user_id,
        max(event_time) as last_seen_at
    from events
    group by user_id
)

select
    md5(f.user_id)          as user_sk,
    f.user_id,
    f.gender,
    f.country,
    f.first_platform,
    f.acquisition_source,
    f.first_event_type,
    f.first_seen_at,
    l.last_seen_at
from first_event_attrs f
inner join last_seen l using (user_id)
