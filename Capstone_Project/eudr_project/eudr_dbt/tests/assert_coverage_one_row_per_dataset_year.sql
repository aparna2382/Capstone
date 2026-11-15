-- Fails if the coverage table has duplicate or missing rows:
-- every dataset must have exactly one row for each year 2020-2025.

with counts as (

    select source_dataset, trade_year, count(*) as n
    from {{ ref('prep_coverage') }}
    group by source_dataset, trade_year

)

select * from counts where n <> 1

union all

select source_dataset, null::int, count(*)
from {{ ref('prep_coverage') }}
group by source_dataset
having count(*) <> 6