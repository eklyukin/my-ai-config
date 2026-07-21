# SQLMesh MODEL Block Reference

A model file is a `MODEL (...)` block followed by a SQL `SELECT` statement.

## Repo structure

```
projects/xsolla-dwh/models/
  <layer>/
    <schema>/
      <model>.sql
```

Layers:
- `analytics` — editable by analysts (schemas: `dwhp_analytics`, `ps_analytics`, `afs_analytics`, `token_analytics`, `ua_analytics`, etc.)
- `transfer` — editable by analysts
- `raw` — DBA-owned, not editable by analysts
- `stage` — DBA-owned, not editable by analysts

## MODEL properties

| Property | Type | Notes |
|---|---|---|
| `name` | 3-part identifier | `` `xsolla-dwh`.`<schema>`.`<model>` `` |
| `kind` | enum | `FULL`, `VIEW`, `INCREMENTAL_BY_TIME_RANGE`, `INCREMENTAL_BY_UNIQUE_KEY`, `SEED`, `SCD_TYPE_2` |
| `owner` | string | Team code, e.g. `'XAA'` |
| `cron` | cron expression | **Always UTC.** Example: `'15 20 * * 0'` = Sundays 20:15 UTC |
| `grain` | column list | Unique key for deduplication |
| `start` | date string | `'YYYY-MM-DD'` — first date to process |
| `end` | date string | `'YYYY-MM-DD'` — last date to process; past date = model effectively disabled |
| `enabled` | bool | `false` disables the model without deleting the file |
| `description` | string | Human-readable description |
| `audits` | audit list | See audit types below |

## Audit types

- `not_null(columns := [col1, col2])` — fails if any listed column has NULL values
- `unique_values(columns := [col])` — fails if column has duplicate values
- `accepted_values(column := col, is_in := ['val1', 'val2'])` — fails if values outside the list appear

## SQL dialect

BigQuery. The formatter normalizes function names to UPPER and rewrites table references with backticks.

## Minimal VIEW model

```sql
MODEL (
  name `xsolla-dwh`.`<schema>`.`<model>`,
  kind VIEW,
  owner 'XAA'
);

SELECT
  ...
```

## Minimal INCREMENTAL_BY_TIME_RANGE model

```sql
MODEL (
  name `xsolla-dwh`.`<schema>`.`<model>`,
  kind INCREMENTAL_BY_TIME_RANGE (
    time_column event_date
  ),
  owner 'XAA',
  cron '0 6 * * *',
  start '2024-01-01',
  grain [event_date, user_id]
);

SELECT
  event_date,
  user_id,
  ...
WHERE
  event_date BETWEEN @start_ds AND @end_ds
```
