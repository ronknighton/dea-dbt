select f.date_id
from {{ ref('fact_walmart_sales') }} f
left join {{ ref('dim_date') }} d on f.date_id = d.date_id
where d.date_id is null