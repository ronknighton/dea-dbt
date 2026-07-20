select
       store as store_id,
       type as store_type,
       size as store_size
   from {{ source('walmart_raw', 'stores') }}