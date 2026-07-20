{{ config(
    materialized='incremental',
    unique_key=['store_id', 'dept_id'],
    incremental_strategy='merge',
    merge_exclude_columns=['insert_date']
) }}

select distinct
    s.store_id,
    d.dept_id,
    s.store_type,
    s.store_size,
    current_timestamp() as insert_date,
    current_timestamp() as update_date
from {{ ref('stg_walmart__stores') }} s
inner join {{ ref('stg_walmart__department') }} d
    on s.store_id = d.store_id