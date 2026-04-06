{{ config(materialized='table') }}

/*
  fct_events — one row per event, grain: individual user action.

  Built independently from stg_events — no join to dim_users.
  user_sk is derived deterministically as md5(user_id), the same
  function used in dim_users, so the FK relationship holds without
  requiring a join at build time.
*/

with events as (
    select * from {{ ref('stg_events') }}
)

select
    event_id,
    md5(user_id)            as user_sk,
    user_id,
    event_time,
    event_date,
    event_type,
    transaction_category,
    miles_amount,
    platform,
    utm_source,
    country
from events
