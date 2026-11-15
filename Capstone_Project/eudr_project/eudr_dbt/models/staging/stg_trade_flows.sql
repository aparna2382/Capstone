-- Staging: one clean view on the raw Trase table.
-- Only renames, type casts and a few helper columns. No aggregation here.

with source as (

    select * from {{ source('raw', 'fact_trade_flows') }}

)

select
    -- keys and labels
    flow_id,
    source_dataset,
    commodity,
    product_type,
    year::int                                   as trade_year,

    -- origin
    origin_country,
    origin_country_iso2,
    origin_country_iso3,
    origin_level1_type,
    origin_level1,
    origin_level1_id,
    origin_level2_type,
    origin_level2,
    origin_level2_id,
    biome,

    -- supply chain actors
    export_location,
    exporter,
    exporter_group,
    importer,
    importer_group,
    zero_deforestation_commitment,

    -- EU destination
    destination_country,
    destination_iso2,
    destination_iso3,
    destination_basis,

    -- measures
    volume_t,
    trade_value_usd,
    trade_value_type,
    unit_value_usd_per_t,
    land_use_ha,
    deforestation_exposure_ha,
    deforestation_exposure_window_yrs::int      as deforestation_exposure_window_yrs,
    deforestation_annual_ha,
    eudr_relevant_deforestation_ha,

    -- KPI flags
    origin_traceability,
    is_origin_known,
    has_deforestation_data,
    is_deforestation_linked,

    -- quality flags
    flag_value_outlier,
    flag_value_missing,
    flag_name_encoding_fixed,
    (not flag_value_outlier and not flag_value_missing) as is_value_usable

from source