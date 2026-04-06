{{ config(materialized='table') }}

/*
  rpt_miles_economy — miles earned vs redeemed over time + top categories.

  Two complementary views of the miles rewards loop:
    - monthly flow  : miles earned vs redeemed by month
    - category ranks: total miles and transaction count per merchant category

  Grain: (month, event_type) for flow; (transaction_category) for category ranks.
  Builds from fct_events.
*/

with miles_flow as (
    select
        date_trunc('month', event_date)::date           as month,
        event_type,
        sum(miles_amount)                               as total_miles,
        count(*)                                        as transactions,
        null::varchar                                   as transaction_category
    from {{ ref('fct_events') }}
    where event_type in ('miles_earned', 'miles_redeemed')
      and miles_amount is not null
    group by 1, 2
),

category_ranks as (
    select
        null::date                                      as month,
        'miles_earned'                                  as event_type,
        sum(miles_amount)                               as total_miles,
        count(*)                                        as transactions,
        transaction_category
    from {{ ref('fct_events') }}
    where event_type = 'miles_earned'
      and transaction_category is not null
    group by transaction_category
)

select * from miles_flow
union all
select * from category_ranks
order by month, event_type, transaction_category
