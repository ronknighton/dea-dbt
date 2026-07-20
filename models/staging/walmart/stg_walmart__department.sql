select
    store as store_id,
    dept as dept_id,
    date as sales_date,
    weekly_sales,
    isholiday as is_holiday
from {{ source('walmart_raw', 'department') }}