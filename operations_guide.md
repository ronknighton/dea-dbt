# Walmart Pipeline — Operations Guide

Covers two things: how to reload the pipeline when source data changes, and how to deliberately test that the SCD1/SCD2 logic works correctly.

---

## Part 1 — Full Reload Procedure

Use this any time updated or additional source files need to flow through the pipeline.

### 1. Upload source data
Upload the new/updated CSV(s) to the appropriate S3 folder(s) in `dea-walmart-bucket-rhk` (`stores/`, `departments/`, or `fact/`).

### 2. Trigger Snowpipe ingestion
Run for whichever source(s) changed:
```sql
alter pipe walmart_stores_pipe refresh;
alter pipe walmart_department_pipe refresh;
alter pipe walmart_fact_pipe refresh;
```
Confirm each processed:
```sql
select system$pipe_status('walmart_stores_pipe');
select system$pipe_status('walmart_department_pipe');
select system$pipe_status('walmart_fact_pipe');
```
Look for `"pendingFileCount":0` on whichever pipe(s) you triggered.

### 3. Run dbt

**Recommended — single command:**
```
dbt build
```
Runs models, snapshots, and tests together in correct dependency order in one invocation. Safe to use now that this repo is dedicated solely to the Walmart pipeline (`Walmart_E2E`) — no other coursework left in here for a full build to accidentally sweep up.

Confirm `fact_walmart_sales_snapshot` actually ran as part of it — look for a `snapshot` line in the output alongside the `run` and `test` lines. This project is on a preview build of the Fusion engine, which has already shown a couple of rough edges (the `relationships` test bug, a `NoNodesForSelectionCriteria` false-negative) — worth a visual check rather than assuming a clean exit code means every node ran.

**Fallback — granular sequence, useful for isolating a failing step:**
```
dbt run --select stg_walmart__stores stg_walmart__department stg_walmart__fact
dbt run --select dim_date dim_store
dbt run --select int_walmart__sales_enriched fact_walmart_sales
dbt snapshot --select fact_walmart_sales_snapshot
dbt run --select fact_walmart_sales_v2_snapshot
```
(Or condense the middle steps with `dbt run --select int_walmart__sales_enriched+` once staging and dims are confirmed current.)

**Not covered by either dbt command:** steps 1 and 2 above (S3 upload, Snowpipe refresh) are AWS/Snowflake operations outside dbt's control — no dbt command reaches back to touch S3 or run `ALTER PIPE REFRESH`. A true single "reload everything" command would require an external orchestrator (e.g., a Snowflake Task/stored procedure also triggering a dbt Cloud job via its API) sitting above both systems — real added infrastructure, and the same complexity deliberately cut from this project back in Phase 1 for being overkill on a static historical dataset. Realistic minimum right now: manual upload → manual pipe refresh → one `dbt build`.

### 4. Verify
```sql
select count(*) from walmart_db.raw.stores;
select count(*) from walmart_db.raw.department;
select count(*) from walmart_db.raw.fact;

select count(*) from walmart_db.marts.dim_date;
select count(*) from walmart_db.marts.dim_store;
select count(*) from walmart_db.marts.fact_walmart_sales;
select count(*) from walmart_db.marts.fact_walmart_sales_v2_snapshot;
```
Then run the full test suite:
```
dbt test
```

---

## Part 2 — SCD1 / SCD2 Validation Test

Deliberately changes source data to prove the dims correctly overwrite (SCD1) and the fact tables correctly version (SCD2). Run this once per significant pipeline change, or any time the SCD logic itself is modified.

### Test A — SCD1 upsert on `dim_store`
```sql
update walmart_db.raw.stores set size = size + 10000 where store = 1;
```
```
dbt run --select dim_store
```
```sql
select * from walmart_db.marts.dim_store where store_id = 1;
```
**Pass condition:** one row per store_id/dept_id combo for Store 1, `store_size` reflects the new value, no duplicate rows. This confirms overwrite-in-place, no history kept — correct SCD1 behavior.

### Test B — SCD2 versioning on `fact_walmart_sales` (pre-hook version)
```sql
update walmart_db.raw.department
set weekly_sales = weekly_sales + 500
where store = 1 and dept = 1 and date = '2010-02-05';
```
```
dbt run --select int_walmart__sales_enriched+
```
```sql
select store_id, dept_id, date_id, store_weekly_sales, vrsn_start_date, vrsn_end_date
from walmart_db.marts.fact_walmart_sales
where store_id = 1 and dept_id = 1 and date_id = 20100205
order by vrsn_start_date;
```
**Pass condition:** two rows returned. Original row now shows `vrsn_end_date` = today (closed). New row shows the corrected `store_weekly_sales`, `vrsn_start_date` = today, `vrsn_end_date` = `9999-12-31` (open).

### Test C — SCD2 versioning on `fact_walmart_sales_v2_snapshot` (dbt snapshot version)
```
dbt snapshot --select fact_walmart_sales_snapshot
dbt run --select fact_walmart_sales_v2_snapshot
```
```sql
select store_id, dept_id, date_id, store_weekly_sales, vrsn_start_date, vrsn_end_date
from walmart_db.marts.fact_walmart_sales_v2_snapshot
where store_id = 1 and dept_id = 1 and date_id = 20100205
order by vrsn_start_date;
```
**Pass condition:** same shape as Test B — two rows, old one closed, new one open with the corrected value. Confirms the snapshot-based approach produces an equivalent result to the pre-hook approach.

### Test D — confirm both fact tables still agree after the change
```sql
select store_id, dept_id, date_id, store_weekly_sales, store_temperature, fuel_price,
       markdown1, markdown2, markdown3, markdown4, markdown5, cpi, unemployment
from walmart_db.marts.fact_walmart_sales
where vrsn_end_date = '9999-12-31'
except
select store_id, dept_id, date_id, store_weekly_sales, store_temperature, fuel_price,
       markdown1, markdown2, markdown3, markdown4, markdown5, cpi, unemployment
from walmart_db.marts.fact_walmart_sales_v2_snapshot
where vrsn_end_date = '9999-12-31';
```
**Pass condition:** zero rows. Confirms the two independently-built SCD2 approaches still agree on current-state data after a real change, not just on the original static load.

### 5. Run `dbt test` once more
```
dbt test
```
All tests should still pass — confirms the deliberate change didn't break referential integrity between the fact and dim tables.
