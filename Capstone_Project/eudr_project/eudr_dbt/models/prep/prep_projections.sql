-- Projections: fills the NO DATA years in prep_coverage with clearly labelled estimates.
-- Real values are never changed. Every measure gets a value_type and a method,
-- so Tableau can show projections differently (dashed / lighter) and explain them.
--
-- Methods
--   volume:        average of the last 3 real years (needs >= 3 real years)
--   deforestation: intensity ratio = ha per tonne from the last (up to) 3 real years
--                  x the year's volume (needs >= 2 real years of deforestation data)
--   EUDR-relevant: same intensity method, only where the metric exists, only 2021+

{% set min_years_volume = 3 %}
{% set min_years_intensity = 2 %}
{% set lookback_years = 3 %}

with coverage as (

    select * from {{ ref('prep_coverage') }}

),

-- real volume points: reported years plus real zeros (year covered, no EU trade)
real_volume as (

    select
        source_dataset,
        trade_year,
        coalesce(volume_t, 0) as volume_t,
        row_number() over (partition by source_dataset order by trade_year desc) as recency
    from coverage
    where trade_status in ('ACTUAL', 'ZERO EU TRADE')

),

volume_basis as (

    select
        source_dataset,
        count(*)                                                        as n_real_volume_years,
        avg(volume_t) filter (where recency <= {{ lookback_years }})    as avg_volume_recent_t
    from real_volume
    group by source_dataset

),

-- real deforestation intensity (ha per tonne), years with reported deforestation
real_deforestation as (

    select
        source_dataset,
        volume_t,
        deforestation_exposure_ha,
        row_number() over (partition by source_dataset order by trade_year desc) as recency
    from coverage
    where deforestation_status = 'ACTUAL'
      and volume_t > 0

),

deforestation_basis as (

    select
        source_dataset,
        count(*)                                                        as n_real_deforestation_years,
        sum(deforestation_exposure_ha) filter (where recency <= {{ lookback_years }})
          / nullif(sum(volume_t) filter (where recency <= {{ lookback_years }}), 0)
                                                                        as deforestation_ha_per_t
    from real_deforestation
    group by source_dataset

),

real_eudr as (

    select
        source_dataset,
        volume_t,
        eudr_relevant_deforestation_ha,
        row_number() over (partition by source_dataset order by trade_year desc) as recency
    from coverage
    where eudr_deforestation_status = 'ACTUAL'
      and volume_t > 0

),

eudr_basis as (

    select
        source_dataset,
        count(*)                                                        as n_real_eudr_years,
        sum(eudr_relevant_deforestation_ha) filter (where recency <= {{ lookback_years }})
          / nullif(sum(volume_t) filter (where recency <= {{ lookback_years }}), 0)
                                                                        as eudr_ha_per_t
    from real_eudr
    group by source_dataset

),

-- step 1: volume (actual or projected)
with_volume as (

    select
        c.*,
        case
            when c.trade_status = 'ACTUAL'                               then c.volume_t
            when c.trade_status = 'ZERO EU TRADE'                        then 0
            when vb.n_real_volume_years >= {{ min_years_volume }}        then greatest(vb.avg_volume_recent_t, 0)
        end                                                              as volume_final_t,
        case
            when c.trade_status in ('ACTUAL', 'ZERO EU TRADE')           then 'ACTUAL'
            when vb.n_real_volume_years >= {{ min_years_volume }}        then 'PROJECTED'
            else 'NO DATA'
        end                                                              as volume_value_type,
        case
            when c.trade_status = 'ACTUAL'                               then 'Reported (Trase)'
            when c.trade_status = 'ZERO EU TRADE'                        then 'Reported zero (no EU shipments)'
            when vb.n_real_volume_years >= {{ min_years_volume }}        then 'Average of last {{ lookback_years }} reported years'
            else 'Not enough reported years to project (< {{ min_years_volume }})'
        end                                                              as volume_method
    from coverage as c
    left join volume_basis as vb using (source_dataset)

)

-- step 2: deforestation measures, using the volume from step 1
select
    v.source_dataset,
    v.commodity,
    v.origin_country,
    v.origin_country_iso2,
    v.trade_year,
    v.trade_status,
    v.deforestation_exposure_window_yrs,

    -- volume
    v.volume_final_t                                                     as volume_t,
    v.volume_value_type,
    v.volume_method,

    -- deforestation exposure (risk signal, incl. pre-2020 clearing)
    case
        when v.deforestation_status = 'ACTUAL'                           then v.deforestation_exposure_ha
        when v.deforestation_status = 'ZERO EU TRADE'                    then 0
        when v.deforestation_status = 'NO DATA'
         and v.volume_final_t is not null
         and db.n_real_deforestation_years >= {{ min_years_intensity }}  then greatest(v.volume_final_t * db.deforestation_ha_per_t, 0)
    end                                                                  as deforestation_exposure_ha,
    case
        when v.deforestation_status = 'NOT IN DATASET'                   then 'NOT IN DATASET'
        when v.deforestation_status in ('ACTUAL', 'ZERO EU TRADE')       then 'ACTUAL'
        when v.volume_final_t is not null
         and db.n_real_deforestation_years >= {{ min_years_intensity }}  then 'PROJECTED'
        else 'NO DATA'
    end                                                                  as deforestation_value_type,
    case
        when v.deforestation_status = 'NOT IN DATASET'                   then 'Metric not published for this commodity/origin'
        when v.deforestation_status = 'ACTUAL'                           then 'Reported (Trase)'
        when v.deforestation_status = 'ZERO EU TRADE'                    then 'Reported zero (no EU shipments)'
        when v.volume_final_t is not null
         and db.n_real_deforestation_years >= {{ min_years_intensity }}
            then 'Intensity ratio (ha per t, last reported years) x '
                 || lower(v.volume_value_type) || ' volume'
        else 'Not enough reported years to project'
    end                                                                  as deforestation_method,
    db.deforestation_ha_per_t,

    -- EUDR-relevant deforestation (clearing after 31 Dec 2020)
    case
        when v.eudr_deforestation_status = 'ACTUAL'                      then v.eudr_relevant_deforestation_ha
        when v.eudr_deforestation_status = 'ZERO EU TRADE'               then 0
        when v.eudr_deforestation_status = 'NO DATA'
         and v.volume_final_t is not null
         and eb.n_real_eudr_years >= {{ min_years_intensity }}           then greatest(v.volume_final_t * eb.eudr_ha_per_t, 0)
    end                                                                  as eudr_relevant_deforestation_ha,
    case
        when v.eudr_deforestation_status in ('NOT IN DATASET', 'NOT APPLICABLE (PRE-CUTOFF)')
                                                                         then v.eudr_deforestation_status
        when v.eudr_deforestation_status in ('ACTUAL', 'ZERO EU TRADE')  then 'ACTUAL'
        when v.volume_final_t is not null
         and eb.n_real_eudr_years >= {{ min_years_intensity }}           then 'PROJECTED'
        else 'NO DATA'
    end                                                                  as eudr_value_type,

    -- convenience flag for Tableau filters
    (v.volume_value_type = 'PROJECTED'
     or (v.deforestation_status = 'NO DATA' and v.volume_final_t is not null
         and db.n_real_deforestation_years >= {{ min_years_intensity }})
     or (v.eudr_deforestation_status = 'NO DATA' and v.volume_final_t is not null
         and eb.n_real_eudr_years >= {{ min_years_intensity }}))         as has_projected_values

from with_volume as v
left join deforestation_basis as db using (source_dataset)
left join eudr_basis          as eb using (source_dataset)