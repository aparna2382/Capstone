-- Fails if any volume or deforestation value (actual or projected) is negative.

select *
from {{ ref('prep_projections') }}
where volume_t < 0
   or deforestation_exposure_ha < 0
   or eudr_relevant_deforestation_ha < 0