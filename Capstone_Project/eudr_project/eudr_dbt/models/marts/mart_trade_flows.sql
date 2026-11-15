-- Detailed reported flows for the dashboard filters (year, commodity, product,
-- origin country/region, EU destination, exporter group). Reported data only.

select
    trade_year,
    commodity,
    product_type,
    origin_country,
    origin_country_iso2,
    origin_country_iso3,
    origin_level1_type,
    origin_level1,
    origin_traceability,
    destination_country,
    destination_iso2,
    destination_iso3,
    destination_basis,
    exporter_group,
    zero_deforestation_commitment,

    count(*)                                                        as flow_count,
    sum(volume_t)                                                   as volume_t,
    sum(trade_value_usd) filter (where is_value_usable)             as trade_value_usd,
    max(trade_value_type)                                           as trade_value_type,
    sum(deforestation_exposure_ha)                                  as deforestation_exposure_ha,
    max(deforestation_exposure_window_yrs)                          as deforestation_exposure_window_yrs,
    sum(eudr_relevant_deforestation_ha)                             as eudr_relevant_deforestation_ha,
    sum(volume_t) filter (where is_origin_known)                    as volume_origin_known_t,
    sum(volume_t) filter (where has_deforestation_data)             as volume_with_deforestation_data_t,
    sum(volume_t) filter (where is_deforestation_linked)            as volume_deforestation_linked_t

from {{ ref('stg_trade_flows') }}
group by
    trade_year, commodity, product_type,
    origin_country, origin_country_iso2, origin_country_iso3,
    origin_level1_type, origin_level1, origin_traceability,
    destination_country, destination_iso2, destination_iso3, destination_basis,
    exporter_group, zero_deforestation_commitment