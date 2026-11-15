-- KPI dashboard + trend lines: one row per commodity, origin country and year (2020-2025).
-- Includes projected years (value_type = PROJECTED) and data gaps (NO DATA),
-- so Tableau can draw actual values solid and projections dashed.

with projections as (

    select * from {{ ref('prep_projections') }}

),

coverage as (

    select * from {{ ref('prep_coverage') }}

),

countries as (

    select iso2, iso3 from {{ ref('dim_country') }}

)

select
    p.source_dataset,
    p.commodity,
    p.origin_country,
    p.origin_country_iso2,
    co.iso3                                                         as origin_country_iso3,
    p.trade_year,
    p.trade_status,

    -- volume
    p.volume_t,
    p.volume_value_type,
    p.volume_method,

    -- deforestation exposure (risk signal, includes clearing before 2020)
    p.deforestation_exposure_ha,
    p.deforestation_value_type,
    p.deforestation_method,
    p.deforestation_exposure_window_yrs,
    case
        when p.deforestation_exposure_window_yrs is not null
            then p.deforestation_exposure_window_yrs || '-yr exposure (incl. pre-2020 clearing)'
    end                                                             as deforestation_metric_label,
    p.deforestation_exposure_ha / nullif(p.volume_t, 0) * 1000      as deforestation_ha_per_1000t,

    -- EUDR-relevant deforestation (clearing after 31 Dec 2020)
    p.eudr_relevant_deforestation_ha,
    p.eudr_value_type,
    p.eudr_relevant_deforestation_ha / nullif(p.volume_t, 0) * 1000 as eudr_ha_per_1000t,

    -- traceability KPIs (only for reported years; not projected)
    c.volume_origin_known_t,
    c.volume_origin_known_t / nullif(c.volume_t, 0)                 as share_volume_origin_known,
    c.volume_with_deforestation_data_t,
    c.volume_deforestation_linked_t,
    c.volume_deforestation_linked_t
        / nullif(c.volume_with_deforestation_data_t, 0)             as share_volume_deforestation_linked,

    p.has_projected_values

from projections as p
left join coverage as c
    on  c.source_dataset = p.source_dataset
    and c.trade_year     = p.trade_year
left join countries as co
    on  co.iso2 = p.origin_country_iso2