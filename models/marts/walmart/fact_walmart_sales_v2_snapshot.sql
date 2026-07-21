select
    store_id,
    dept_id,
    date_id,
    store_weekly_sales,
    store_temperature,
    fuel_price,
    markdown1, markdown2, markdown3, markdown4, markdown5,
    cpi,
    unemployment,
    dbt_valid_from as vrsn_start_date,
    coalesce(dbt_valid_to, '9999-12-31'::date) as vrsn_end_date,
    dbt_valid_from as insert_date,
    dbt_updated_at as update_date
from {{ ref('fact_walmart_sales_snapshot') }}