-- Data gaps view: what is missing per commodity, origin and year, and how much
-- EU import volume (reported or projected) is affected. Supports the EUDR message:
-- "this data needs to be available before the EUDR deadline".

with projections as (

    select * from {{ ref('prep_projections') }}

)

select
    source_dataset,
    commodity,
    origin_country,
    origin_country_iso2,
    trade_year,
    volume_t,
    volume_value_type,
    deforestation_value_type,
    eudr_value_type,

    volume_value_type <> 'ACTUAL'                                   as is_trade_data_missing,
    deforestation_value_type in ('NO DATA', 'NOT IN DATASET', 'PROJECTED')
                                                                    as is_deforestation_data_missing,
    trade_year >= 2021
      and eudr_value_type in ('NO DATA', 'NOT IN DATASET', 'PROJECTED')
                                                                    as is_eudr_data_missing,

    -- volume affected by the gap (uses projected volume where needed)
    case when deforestation_value_type in ('NO DATA', 'NOT IN DATASET', 'PROJECTED')
         then volume_t end                                          as volume_without_reported_deforestation_t,
    case when trade_year >= 2021
          and eudr_value_type in ('NO DATA', 'NOT IN DATASET', 'PROJECTED')
         then volume_t end                                          as volume_without_reported_eudr_data_t,

    -- one readable label for tooltips / colour
    case
        when volume_value_type = 'NO DATA'                          then 'No trade data'
        when deforestation_value_type = 'NOT IN DATASET'            then 'No deforestation data published'
        when volume_value_type = 'PROJECTED'                        then 'Trade data not yet published (projected)'
        when deforestation_value_type = 'PROJECTED'                 then 'Deforestation data not yet published (projected)'
        when trade_year >= 2021 and eudr_value_type = 'NOT IN DATASET'
                                                                    then 'No post-2020 (EUDR) deforestation metric'
        else 'Complete'
    end                                                             as gap_label

from projections