-- Our projection method only fills years AFTER the last reported year.
-- This test fails if a NO DATA year sits between two reported years
-- (that would need interpolation instead - e.g. after a future data update).

select c.source_dataset, c.trade_year
from {{ ref('prep_coverage') }} as c
where c.trade_status = 'NO DATA'
  and exists (select 1 from {{ ref('prep_coverage') }} b
              where b.source_dataset = c.source_dataset
                and b.trade_year < c.trade_year
                and b.trade_status <> 'NO DATA')
  and exists (select 1 from {{ ref('prep_coverage') }} a
              where a.source_dataset = c.source_dataset
                and a.trade_year > c.trade_year
                and a.trade_status <> 'NO DATA')