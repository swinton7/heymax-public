/*
  assert_net_growth_formula_balances

  Validates that net_growth = new_users + resurrected_users - churned_users
  for every row in rpt_net_growth.

  Any row returned = test failure.
*/

select
    period_start,
    net_growth,
    new_users + resurrected_users - churned_users as calculated,
    net_growth - (new_users + resurrected_users - churned_users) as diff
from {{ ref('rpt_net_growth') }}
where net_growth != (new_users + resurrected_users - churned_users)
