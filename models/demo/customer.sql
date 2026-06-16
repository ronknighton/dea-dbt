{{config(materialized='table')}}

with customer_src as
(
    select
    CUSTOMER_ID,
    FIRST_NAME,
    LAST_NAME,
    EMAIL,
    PHONE,
    COUNTRY,
    CREATED_AT,
    CURRENT_TIMESTAMP AS INSERT_DTS
    from {{source('customer','CUSTOMER_SRC')}}
)
SELECT * FROM customer_src