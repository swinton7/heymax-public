/*
  assert_no_user_double_counted_in_cohorts

  Validates that no user appears in more than one cohort type
  (new / retained / resurrected / churned) for the same
  (period_grain, period_start) combination.

  Re-derives the classified CTE from int_user_activity_periods — the same
  logic used in rpt_growth_accounting — and checks for duplicates at the
  user level before dimensional aggregation.

  Any row returned = test failure.
*/

with windowed as (
    select
        user_id,
        period_grain,
        period_start,
        prior_period_start,
        next_period_start,
        lag(period_start) over (
            partition by user_id, period_grain
            order by period_start
        )                                           as lag_period_start,
        lead(period_start) over (
            partition by user_id, period_grain
            order by period_start
        )                                           as lead_period_start,
        min(period_start) over (
            partition by user_id, period_grain
        )                                           as first_period_start
    from {{ ref('int_user_activity_periods') }}
),

classified as (
    select
        user_id,
        period_grain,
        period_start,
        case
            when period_start = first_period_start     then 'new'
            when lag_period_start = prior_period_start then 'retained'
            else                                            'resurrected'
        end                                         as cohort_type
    from windowed

    union all

    select
        user_id,
        period_grain,
        next_period_start                           as period_start,
        'churned'                                   as cohort_type
    from windowed
    where lead_period_start is null
       or lead_period_start != next_period_start
)

select
    user_id,
    period_grain,
    period_start,
    count(*) as cohort_count
from classified
group by 1, 2, 3
having count(*) > 1
