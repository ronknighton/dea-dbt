{% snapshot fact_walmart_sales_snapshot %}
{{
    config(
        target_schema='snapshots',
        target_database='walmart_db',
        unique_key="store_id || '-' || dept_id || '-' || date_id",
        strategy='check',
        check_cols=['store_weekly_sales', 'store_temperature', 'fuel_price', 'cpi', 'unemployment', 'markdown1', 'markdown2', 'markdown3', 'markdown4', 'markdown5']
    )
}}
select * from {{ ref('int_walmart__sales_enriched') }}
{% endsnapshot %}