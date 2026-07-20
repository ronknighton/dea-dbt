{{ config(materialized='view') }}

select
    d.store_id,
    d.dept_id,
    dd.date_id,
    d.weekly_sales as store_weekly_sales,
    f.store_temperature,
    f.fuel_price,
    f.markdown1, f.markdown2, f.markdown3, f.markdown4, f.markdown5,
    f.cpi,
    f.unemployment
from {{ ref('stg_walmart__department') }} d
left join {{ ref('stg_walmart__fact') }} f
    on d.store_id = f.store_id and d.sales_date = f.sales_date
inner join {{ ref('dim_date') }} dd
    on d.sales_date = dd.store_date