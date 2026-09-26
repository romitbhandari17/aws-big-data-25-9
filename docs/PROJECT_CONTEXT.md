# Project Context: AWS Big Data Platform (E-Commerce Analytics)

## 1. Background & Motivation

This project is derived from notes on **DynamoDB vs Spark vs Glue vs Redshift**,
using an Amazon-style e-commerce order processing scenario as the running example.

Key premise from the notes:
- DynamoDB is not used because data is "Big Data" — it's used because the
  **application** needs high-scale, low-latency reads/writes for operational data
  (e.g., placing/updating orders).
- Operational data is periodically copied/exported to **S3** so it can be
  processed at scale for analytics ("Big Data" workloads).
- Flow from the notes: `DynamoDB -> Export/Streams/ETL -> S3 Data Lake -> (further processing)`.

## 2. Phased Approach

**Phase 1 (this phase — build now):**
Start with the analytics side of the platform, independent of the live
operational store:
- Land raw/batch data for **orders, customers, and products** directly into an
  **S3 Data Lake**.
- Process this data at scale using **AWS EMR + PySpark** (cleaning,
  transformation, joins, aggregations).
- Load curated/transformed data into **Amazon Redshift** for analytical
  (OLAP-style) querying and reporting.

**Phase 2 (future):**
- Introduce **DynamoDB** as the operational data store for the live
  application (e.g., order service handling high-volume reads/writes such as
  `Get order`, `Update status`, `Get all orders for customer`).
- Implement export of DynamoDB data (via DynamoDB Streams, DMS, or scheduled
  export) into the same S3 Data Lake, feeding the existing EMR/Redshift
  pipeline instead of (or in addition to) the batch-loaded data from Phase 1.

This project starts with Phase 1 only. Phase 2 will be added later as a
distinct milestone once the data lake + processing + analytics foundation is
working end to end.

## 3. Architecture (Phase 1)

```
        Orders / Customers / Products
                (raw/batch data)
                      |
                      v
              S3 Data Lake (raw zone)
                      |  (new file under raw/orders/ triggers)
                      v
              Lambda (S3 event -> emr add-steps)
                      |
                      v
          AWS EMR + PySpark (processing)
        (clean, transform, join, aggregate)
                      |
                      v
              S3 Data Lake (curated zone)
                      |
                      v
             Amazon Redshift (JDBC load)
                      |
                      v
            Analytical / BI queries
```

## 4. Data Domains

| Domain     | Description                                              |
|------------|-----------------------------------------------------------|
| Customers  | Customer master data (id, name, contact, segment, etc.)   |
| Products   | Product catalog (id, name, category, price, etc.)         |
| Orders     | Order transactions (order id, customer id, product, amount, status, timestamps) |

Reference shape from the notes (illustrative, operational-style record):

```
OrderId   CustomerId   Product   Amount   Status
ORD1001   C101         iPhone   ₹80,000  PLACED
ORD1002   C102         TV       ₹50,000  SHIPPED
ORD1003   C103         Laptop   ₹70,000  DELIVERED
```

## 5. S3 Data Lake Layout (proposed convention)

- `s3://<bucket>/raw/orders/`
- `s3://<bucket>/raw/customers/`
- `s3://<bucket>/raw/products/`
- `s3://<bucket>/curated/orders/`
- `s3://<bucket>/curated/customers/`
- `s3://<bucket>/curated/products/`

Raw zone holds untouched ingested data; curated zone holds EMR/PySpark
output ready for Redshift loading. Layout may evolve as implementation
proceeds (e.g., partitioning by date/region).

## 6. Processing & Analytics

- **AWS EMR + PySpark**: primary big data processing engine for Phase 1 —
  batch ETL/ELT over the S3 raw zone (cleaning, deduplication, joins across
  orders/customers/products, aggregations) producing the curated zone.
- **Amazon Redshift**: destination for curated data; used for analytical
  queries, reporting, and dashboards (e.g., sales by product/customer,
  order trends, revenue analysis).

### 6.1 PySpark Processing Details (EMR jobs)

Implemented in `src/spark/jobs/process_orders.py` (see `src/spark/README.md`
for how to run it). It handles the following kinds of processing on the
raw orders/customers/products data before it lands in the curated zone:

- **Data ingestion & schema handling**
  - Read raw files (CSV/JSON/Parquet) from the S3 raw zone.
  - Enforce/validate schema (data types, required fields) for each domain.

- **Data cleaning**
  - Handle nulls/missing values (e.g., missing customer id, product id).
  - Deduplicate records (e.g., duplicate order ids from repeated ingestion).
  - Standardize formats (dates/timestamps, currency/amount fields, status
    values, text casing).
  - Filter out invalid/malformed records (e.g., negative amounts, unknown
    status codes).

- **Transformation**
  - Type casting and column renaming to match curated schema/Redshift table
    definitions.
  - Derived/calculated columns (e.g., order year/month/day for partitioning,
    discounted vs. gross amount).
  - Status/category normalization (e.g., mapping raw status codes to a
    standard enum: PLACED, SHIPPED, DELIVERED, CANCELLED).

- **Joins across domains**
  - Join orders with customers (on `CustomerId`) to enrich orders with
    customer attributes (segment, region, etc.).
  - Join orders with products (on `ProductId`) to enrich orders with product
    attributes (category, unit price, brand).
  - Produce a denormalized "orders enriched" dataset for easier downstream
    querying.

- **Aggregations**
  - Revenue/sales aggregations by product, customer, category, region, and
    time period (daily/monthly/yearly).
  - Order volume and status-distribution metrics (e.g., counts of PLACED /
    SHIPPED / DELIVERED / CANCELLED orders).
  - Customer-level metrics (e.g., total spend, order count, average order
    value) for use in reporting.

- **Output & partitioning**
  - Write curated output back to S3 in an analytics-friendly format
    (Parquet), partitioned (e.g., by year/month or region) to optimize
    Redshift `COPY` performance and downstream query efficiency.
  - Curated datasets are designed to map directly onto Redshift tables used
    for analytical queries.

## 7. Folder Structure & Conventions

To keep the demo easy to follow, the project is organized so each AWS
service has its own clearly separated code and infra, one concept per
folder — no mixing of unrelated logic in a single place:

```
src/
  spark/              PySpark job scripts run on EMR (Phase 1 processing)
  lambda/
    emr.py            Lambda handler: S3 event -> submits the EMR spark-submit step
  redshift/           Redshift SQL: table DDL + load (COPY) scripts
  sqs/                Optional/example only - see note below
  infra/
    provider.tf       Terraform + AWS provider config (local execution/state)
    variables.tf      Root-level input variables (e.g., aws_region)
    envs/
      dev/
        dev.tfvars    Environment-specific variable values (dev)
    modules/
      s3/
        s3.tf         S3 data lake buckets (raw + curated zones)
        iam.tf        IAM for S3 access
      redshift/
        redshift.tf   Redshift cluster
        iam.tf        IAM for Redshift
      spark/
        emr.tf         EMR cluster running the PySpark jobs
        iam.tf         IAM for EMR
      lambda/
        lambda.tf      S3-event-triggered Lambda that submits the EMR step
        iam.tf         IAM for the Lambda's EMR permissions
      sqs/
        sqs.tf         Optional queue (see note below)
        iam.tf         IAM for SQS
```

Rules followed for this structure:
- One module per AWS service; each module owns its own `iam.tf` for the
  IAM roles/policies that service needs (kept next to what uses it, not
  centralized, so it's easy to see who has access to what).
- `src/spark`, `src/redshift`, `src/sqs` hold the actual code/scripts;
  `src/infra` holds the Terraform that provisions the AWS resources.
- `src/infra/envs/<env>` holds environment-specific values only
  (e.g., `dev.tfvars`); the reusable resource definitions live in
  `src/infra/modules/<service>`.
- Kept intentionally minimal/commented at this stage — folders and files
  exist as scaffolding with explanatory comments only; implementation is
  added incrementally so the project stays easy to follow for a live demo.

### Is SQS needed for Phase 1?

No. SQS is a message-queue/decoupling service, not a big-data processing
service. It would only be relevant for **orchestration** (e.g., an S3
upload event pushing a message to a queue that triggers an EMR step), not
for the core Phase 1 pipeline (S3 -> EMR/PySpark -> Redshift). At this
demo's scale, EMR jobs can be triggered directly without a queue. The
`src/sqs` and `infra/modules/sqs` folders are kept only as an optional/
example scaffold and are **not** part of the required Phase 1 services.

**Phase 1 required services: S3, EMR (PySpark), Redshift, Lambda (S3-event
trigger), and IAM only.**

## 8. Out of Scope for Now

- DynamoDB operational store and application-facing order service (Phase 2).
- DynamoDB -> S3 export mechanism (Streams/DMS/scheduled export) (Phase 2).
- Real-time/streaming ingestion (not indicated by current notes; batch-first
  approach for Phase 1).

## 9. Source Notes

Original notes: `docs/aws-big-data-notes.pages`
(topic: "DynamoDB vs Spark vs Glue vs Redshift", e-commerce orders example).
