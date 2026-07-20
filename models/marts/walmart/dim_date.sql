{{
    config(
        materialized='incremental',
        unique_key='date_id',
        incremental_strategy='merge',
        merge_exclude_columns=['insert_date']
    )
}}

select distinct
    to_number(to_char(sales_date, 'YYYYMMDD')) as date_id,
    sales_date as store_date,
    is_holiday,
    current_timestamp() as insert_date,
    current_timestamp() as update_date
from {{ ref('stg_walmart__department') }}