-- Fails if a projection ever changes a reported (actual) value.
-- Uses a small tolerance (0.001) because decimal sums can differ in the
-- last digits when the database adds the same numbers in a different order.

{% set tolerance = 0.001 %}

select
    c.source_dataset,
    c.trade_year,
    c.volume_t                    as actual_volume_t,
    p.volume_t                    as projections_volume_t,
    c.deforestation_exposure_ha   as actual_deforestation_ha,
    p.deforestation_exposure_ha   as projections_deforestation_ha
from {{ ref('prep_coverage') }}    as c
join {{ ref('prep_projections') }} as p
    on  p.source_dataset = c.source_dataset
    and p.trade_year     = c.trade_year
where (c.trade_status = 'ACTUAL'
       and ((p.volume_t is null) <> (c.volume_t is null)
            or abs(p.volume_t - c.volume_t) > {{ tolerance }}))
   or (c.deforestation_status = 'ACTUAL'
       and ((p.deforestation_exposure_ha is null) <> (c.deforestation_exposure_ha is null)
            or abs(p.deforestation_exposure_ha - c.deforestation_exposure_ha) > {{ tolerance }}))
   or (c.eudr_deforestation_status = 'ACTUAL'
       and ((p.eudr_relevant_deforestation_ha is null) <> (c.eudr_relevant_deforestation_ha is null)
            or abs(p.eudr_relevant_deforestation_ha - c.eudr_relevant_deforestation_ha) > {{ tolerance }}))