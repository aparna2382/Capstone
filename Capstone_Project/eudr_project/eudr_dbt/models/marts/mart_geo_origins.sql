-- Globe / map view: where EU imports come from.
-- One row per year, commodity, origin country and origin region (state/province/department).
-- Reported data only. Region is 'COUNTRY ONLY' where the dataset has no regional detail.

select
    trade_year,
    commodity,
    origin_country,
    origin_country_iso2,
    origin_country_iso3,
    coalesce(origin_level1_type, 'country')                         as origin_region_type,
    coalesce(origin_level1, 'COUNTRY ONLY')                         as origin_region,
    origin_level1_id                                                as origin_region_id,

    sum(volume_t)                                                   as volume_t,
    sum(deforestation_exposure_ha)                                  as deforestation_exposure_ha,
    max(deforestation_exposure_window_yrs)                          as deforestation_exposure_window_yrs,
    sum(eudr_relevant_deforestation_ha)                             as eudr_relevant_deforestation_ha,
    sum(deforestation_exposure_ha) / nullif(sum(volume_t), 0) * 1000
                                                                    as deforestation_ha_per_1000t,
    sum(volume_t) filter (where is_origin_known) / nullif(sum(volume_t), 0)
                                                                    as share_volume_origin_known

from {{ ref('stg_trade_flows') }}
group by
    trade_year, commodity,
    origin_country, origin_country_iso2, origin_country_iso3,
    origin_level1_type, origin_level1, origin_level1_id