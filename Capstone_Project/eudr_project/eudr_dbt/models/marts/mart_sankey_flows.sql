-- Sankey chart: EU import flows in two steps
--   step 1: origin country -> commodity
--   step 2: commodity      -> EU destination country
-- One row per link (source -> target) and year. Reported data only.

with flows as (

    select
        trade_year,
        commodity,
        origin_country,
        destination_country,
        volume_t,
        deforestation_exposure_ha
    from {{ ref('stg_trade_flows') }}

),

step_1 as (

    select
        trade_year,
        1                                as link_step,
        'Origin -> Commodity'            as link_type,
        origin_country                   as source_node,
        commodity                        as target_node,
        commodity,
        origin_country,
        cast(null as text)               as destination_country,
        sum(volume_t)                    as volume_t,
        sum(deforestation_exposure_ha)   as deforestation_exposure_ha
    from flows
    group by trade_year, origin_country, commodity

),

step_2 as (

    select
        trade_year,
        2                                as link_step,
        'Commodity -> EU destination'    as link_type,
        commodity                        as source_node,
        destination_country              as target_node,
        commodity,
        cast(null as text)               as origin_country,
        destination_country,
        sum(volume_t)                    as volume_t,
        sum(deforestation_exposure_ha)   as deforestation_exposure_ha
    from flows
    group by trade_year, commodity, destination_country

)

select * from step_1
union all
select * from step_2