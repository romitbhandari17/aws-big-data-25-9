-- Redshift DDL for the curated orders summary table (Phase 1).
--
-- Spark's JDBC writer (see src/spark/jobs/process_orders.py) can
-- auto-create this table on first write, but it's defined explicitly
-- here so the schema/types/keys are clear for the demo and so it can be
-- created up front (before the first Spark run) if desired.
--
-- Run once against the Redshift cluster (psql, Query Editor v2, etc.)
-- before the first PySpark job run, e.g.:
--   psql -h <redshift-endpoint> -p 5439 -U admin -d orders_analytics -f ddl.sql

CREATE TABLE IF NOT EXISTS orders_summary (
    product_id     VARCHAR(64)     NOT NULL,
    product_name   VARCHAR(256),
    category       VARCHAR(128),
    customer_id    VARCHAR(64)     NOT NULL,
    customer_name  VARCHAR(256),
    total_revenue  DOUBLE PRECISION,
    order_count    BIGINT
)
DISTKEY (customer_id)   -- co-locates rows for the same customer for join/group-by heavy analytics
SORTKEY (product_id, customer_id);
