-- Fails if any trade flow goes to a country that is not in the EU-27 (e.g. the UK).
-- A singular test passes when this query returns 0 rows.

select
    flow_id,
    source_dataset,
    destination_iso2
from {{ ref('stg_trade_flows') }}
where destination_iso2 not in (
    select iso2
    from {{ ref('dim_country') }}
    where is_eu27
)