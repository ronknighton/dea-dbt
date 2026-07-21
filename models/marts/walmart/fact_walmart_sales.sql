{{
    config(
        materialized='incremental',
        incremental_strategy='append',
        pre_hook="{% if is_incremental() %}
            update {{ this }} as tgt
            set vrsn_end_date = current_date(), update_date = current_timestamp()
            from (
                select stg.store_id, stg.dept_id, stg.date_id
                from {{ ref('int_walmart__sales_enriched') }} stg
                inner join {{ this }} cur
                    on cur.store_id = stg.store_id
                    and cur.dept_id = stg.dept_id
                    and cur.date_id = stg.date_id
                    and cur.vrsn_end_date = '9999-12-31'
                where cur.store_weekly_sales is distinct from stg.store_weekly_sales
                   or cur.store_temperature is distinct from stg.store_temperature
                   or cur.fuel_price is distinct from stg.fuel_price
                   or cur.cpi is distinct from stg.cpi
                   or cur.unemployment is distinct from stg.unemployment
                   or cur.markdown1 is distinct from stg.markdown1
                   or cur.markdown2 is distinct from stg.markdown2
                   or cur.markdown3 is distinct from stg.markdown3
                   or cur.markdown4 is distinct from stg.markdown4
                   or cur.markdown5 is distinct from stg.markdown5
            ) changed
            where tgt.store_id = changed.store_id
              and tgt.dept_id = changed.dept_id
              and tgt.date_id = changed.date_id
              and tgt.vrsn_end_date = '9999-12-31'
        {% endif %}"
    )
}}

select
    store_id,
    dept_id,
    date_id,
    store_weekly_sales,
    store_temperature,
    fuel_price,
    markdown1, 
    markdown2, 
    markdown3, 
    markdown4, 
    markdown5,
    cpi,
    unemployment,
    current_date() as vrsn_start_date,
    '9999-12-31'::date as vrsn_end_date,
    current_timestamp() as insert_date,
    current_timestamp() as update_date
from {{ ref('int_walmart__sales_enriched') }} stg
{% if is_incremental() %}
where not exists (
    select 1
    from {{ this }} cur
    where cur.store_id = stg.store_id
      and cur.dept_id = stg.dept_id
      and cur.date_id = stg.date_id
      and cur.vrsn_end_date = '9999-12-31'
)
{% endif %}