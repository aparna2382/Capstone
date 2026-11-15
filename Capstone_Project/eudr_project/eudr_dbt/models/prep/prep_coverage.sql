-- Coverage table: one row per dataset (commodity + origin) and year 2020-2025.
-- Says for every year whether we have ACTUAL data, a real ZERO (Trase covers the
-- year but there were no EU shipments), NO DATA (year not covered yet), or
-- NOT IN DATASET (the metric does not exist for this commodity/origin).
-- This drives the "expected / projected" display in Tableau.

{% set first_year = 2020 %}
{% set last_year = 2025 %}

with catalog as (

    select * from {{ ref('dataset_catalog') }}

),

years as (

    select generate_series({{ first_year }}, {{ last_year }})::int as trade_year

),

-- every dataset x every year, including years without any rows
grid as (

    select
        c.source_dataset,
        c.commodity,
        c.origin_country,
        c.origin_country_iso2,
        c.trase_first_year,
        c.trase_last_year,
        c.has_deforestation_exposure,
        c.deforestation_exposure_window_yrs,
        c.has_eudr_relevant_metric,
        y.trade_year
    from catalog as c
    cross join years as y

),

-- what we actually have per dataset and year (EU-27 only)
actuals as (

    select
        source_dataset,
        trade_year,
        count(*)                                                        as flow_count,
        sum(volume_t)                                                   as volume_t,
        sum(volume_t) filter (where is_origin_known)                    as volume_origin_known_t,
        sum(volume_t) filter (where has_deforestation_data)             as volume_with_deforestation_data_t,
        sum(volume_t) filter (where is_deforestation_linked)            as volume_deforestation_linked_t,
        sum(deforestation_exposure_ha)                                  as deforestation_exposure_ha,
        sum(eudr_relevant_deforestation_ha)                             as eudr_relevant_deforestation_ha,
        bool_or(has_deforestation_data)                                 as any_deforestation_data,
        bool_or(eudr_relevant_deforestation_ha is not null)             as any_eudr_data
    from {{ ref('stg_trade_flows') }}
    group by source_dataset, trade_year

)

select
    g.source_dataset,
    g.commodity,
    g.origin_country,
    g.origin_country_iso2,
    g.trade_year,
    g.trade_year between g.trase_first_year and g.trase_last_year     as is_year_in_dataset,
    g.deforestation_exposure_window_yrs,

    -- status columns (text labels for Tableau colour / filters)
    case
        when a.flow_count > 0                                          then 'ACTUAL'
        when g.trade_year between g.trase_first_year and g.trase_last_year
                                                                       then 'ZERO EU TRADE'
        else 'NO DATA'
    end                                                                as trade_status,

    case
        when not g.has_deforestation_exposure                          then 'NOT IN DATASET'
        when coalesce(a.any_deforestation_data, false)                 then 'ACTUAL'
        when a.flow_count is null
             and g.trade_year between g.trase_first_year and g.trase_last_year
                                                                       then 'ZERO EU TRADE'
        else 'NO DATA'
    end                                                                as deforestation_status,

    case
        when not g.has_eudr_relevant_metric                            then 'NOT IN DATASET'
        when g.trade_year <= 2020                                      then 'NOT APPLICABLE (PRE-CUTOFF)'
        when coalesce(a.any_eudr_data, false)                          then 'ACTUAL'
        when a.flow_count is null
             and g.trade_year between g.trase_first_year and g.trase_last_year
                                                                       then 'ZERO EU TRADE'
        else 'NO DATA'
    end                                                                as eudr_deforestation_status,

    -- actual measures (NULL where there is no data; projections are added later)
    a.flow_count,
    a.volume_t,
    a.volume_origin_known_t,
    a.volume_with_deforestation_data_t,
    a.volume_deforestation_linked_t,
    case when a.any_deforestation_data then a.deforestation_exposure_ha end
                                                                       as deforestation_exposure_ha,
    case when a.any_eudr_data then a.eudr_relevant_deforestation_ha end
                                                                       as eudr_relevant_deforestation_ha

from grid as g
left join actuals as a
    on  a.source_dataset = g.source_dataset
    and a.trade_year     = g.trade_year