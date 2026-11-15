-- Fails if any mart loses or double-counts volume or deforestation compared with staging.
-- Each mart (and each Sankey step) must add up to the same totals.

{% set tolerance = 0.01 %}

with totals as (

    select 'staging' as source, sum(volume_t) as volume_t, sum(deforestation_exposure_ha) as deforestation_ha
    from {{ ref('stg_trade_flows') }}

    union all
    select 'mart_trade_flows', sum(volume_t), sum(deforestation_exposure_ha)
    from {{ ref('mart_trade_flows') }}

    union all
    select 'mart_sankey_flows step ' || link_step, sum(volume_t), sum(deforestation_exposure_ha)
    from {{ ref('mart_sankey_flows') }}
    group by link_step

    union all
    select 'mart_geo_origins', sum(volume_t), sum(deforestation_exposure_ha)
    from {{ ref('mart_geo_origins') }}

    union all
    select 'mart_kpi_yearly (actual)',
           sum(volume_t) filter (where volume_value_type = 'ACTUAL'),
           sum(deforestation_exposure_ha) filter (where deforestation_value_type = 'ACTUAL')
    from {{ ref('mart_kpi_yearly') }}

)

select t.*
from totals as t
cross join (select * from totals where source = 'staging') as s
where abs(t.volume_t - s.volume_t) > {{ tolerance }}
   or abs(t.deforestation_ha - s.deforestation_ha) > {{ tolerance }}