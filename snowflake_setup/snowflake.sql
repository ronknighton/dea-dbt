-- Walmart end-to-end pipeline: S3 ingestion, raw tables, pipes, and mart queries
-- Co-authored with CoCo
--Create DB and schemas
create or replace database walmart_db;
create schema walmart_db.snapshots;
create schema walmart_db.raw;

--Create storage integration for S3 bucket and folders
create or replace storage integration walmart_s3_int
  type = external_stage
  storage_provider = 's3'
  enabled = true
  storage_aws_role_arn = 'arn:aws:iam::<account_id>:role/snowflake-walmart-role'
  storage_allowed_locations = (
    's3://dea-walmart-bucket-rhk/stores/',
    's3://dea-walmart-bucket-rhk/departments/',
    's3://dea-walmart-bucket-rhk/fact/'
  );

desc integration walmart_s3_int;

select system$validate_storage_integration('WALMART_S3_INT', 's3://dea-walmart-bucket-rhk/stores/', 'stores.csv', 'READ');

--create file format for .csv
create or replace file format walmart_csv_format
  type = 'csv'
  field_delimiter = ','
  skip_header = 1
  null_if = ('NA', '')
  empty_field_as_null = true;
  
  desc file format walmart_csv_format;

--Create stages for bucket and folders
create or replace stage stg_walmart_stores
  storage_integration = walmart_s3_int
  url = 's3://dea-walmart-bucket-rhk/stores/'
  file_format = walmart_csv_format;

create or replace stage stg_walmart_department
  storage_integration = walmart_s3_int
  url = 's3://dea-walmart-bucket-rhk/departments/'
  file_format = walmart_csv_format;

create or replace stage stg_walmart_fact
  storage_integration = walmart_s3_int
  url = 's3://dea-walmart-bucket-rhk/fact/'
  file_format = walmart_csv_format;

list @stg_walmart_stores;
list @stg_walmart_department;
list @stg_walmart_fact;

select $1, $2, $3 from @stg_walmart_stores limit 5;
select $1, $2, $3, $4, $5 from @stg_walmart_department limit 5;

--create raw tables
create or replace table walmart_db.raw.stores (
    store number, type varchar, size number,
    _loaded_at timestamp_ntz default current_timestamp(),
    _source_file varchar
);

create or replace table walmart_db.raw.department (
    store number, dept number, date date, weekly_sales number(12,2), isholiday boolean,
    _loaded_at timestamp_ntz default current_timestamp(),
    _source_file varchar
);

create or replace table walmart_db.raw.fact (
    store number, date date, temperature number(5,2), fuel_price number(5,3),
    markdown1 number(10,2), markdown2 number(10,2), markdown3 number(10,2),
    markdown4 number(10,2), markdown5 number(10,2),
    cpi number(10,4), unemployment number(5,3), isholiday boolean,
    _loaded_at timestamp_ntz default current_timestamp(),
    _source_file varchar
);

--create pipes
create or replace pipe walmart_stores_pipe auto_ingest = false as
copy into walmart_db.raw.stores (store, type, size, _source_file)
from (select $1, $2, $3, metadata$filename from @stg_walmart_stores)
file_format = walmart_csv_format;

create or replace pipe walmart_department_pipe auto_ingest = false as
copy into walmart_db.raw.department (store, dept, date, weekly_sales, isholiday, _source_file)
from (select $1, $2, $3, $4, $5, metadata$filename from @stg_walmart_department)
file_format = walmart_csv_format;

create or replace pipe walmart_fact_pipe auto_ingest = false as
copy into walmart_db.raw.fact (store, date, temperature, fuel_price, markdown1, markdown2, markdown3, markdown4, markdown5, cpi, unemployment, isholiday, _source_file)
from (select $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, metadata$filename from @stg_walmart_fact)
file_format = walmart_csv_format;

--refresh pipes
alter pipe walmart_stores_pipe refresh;
alter pipe walmart_department_pipe refresh;
alter pipe walmart_fact_pipe refresh;

--check pipes status
select system$pipe_status('walmart_stores_pipe');
select system$pipe_status('walmart_department_pipe');
select system$pipe_status('walmart_fact_pipe');

--check raw tables for data
select count(*) from walmart_db.raw.stores;      -- expect 45
select count(*) from walmart_db.raw.department;  -- expect 421,570
select count(*) from walmart_db.raw.fact;        -- expect 8,190

select 
    count(*) as total, 
    count(markdown1) as non_null_md1
from walmart_db.raw.fact;


WALMART_DB.PUBLIC_MARTSselect count(*) from walmart_db.marts.dim_store;
select count(*) from (select store_id, dept_id, count(*) from walmart_db.marts.dim_store group by 1,2 having count(*) > 1);  -- expect 0

select count(*) from walmart_db.marts.dim_date;       -- should now show the real data
drop table if exists walmart_db.public_marts.dim_date; -- remove the orphan

select count(*) from walmart_db.marts.dim_store;       -- should now show the real data
drop table if exists walmart_db.public_marts.dim_store; -- remove the orphan

drop schema if exists walmart_db.public_marts;

select count(*) from walmart_db.marts.int_walmart__sales_enriched;  -- expect 421,570
select count(*) from walmart_db.marts.fact_walmart_sales;           -- expect 421,570 (first run, nothing exists yet to trigger the pre-hook)
select count(*) from walmart_db.marts.fact_walmart_sales where vrsn_end_date != '9999-12-31';  -- expect 0


select 
    sales.store_id,
    d_date.is_holiday,
    sum(sales.store_weekly_sales) as sum_sales
from walmart_db.marts.fact_walmart_sales sales
inner join walmart_db.marts.dim_date d_date on d_date.date_id = sales.date_id
group by sales.store_id, d_date.is_holiday
order by sales.store_id, d_date.is_holiday 