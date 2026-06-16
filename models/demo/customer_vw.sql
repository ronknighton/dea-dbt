{{config(materialized='view')}}

SELECT * FROM {{ ref('customer') }}
where country='USA'