# src/spark

PySpark job scripts that run on AWS EMR (Phase 1 processing layer).

## jobs/process_orders.py

Reads raw orders/customers/products data from the S3 raw zone, cleans it,
joins the three domains, aggregates revenue/order-count by product and
customer, writes the results to the S3 curated zone, and loads the
aggregated summary into Redshift for analytical querying (see
docs/PROJECT_CONTEXT.md, section 6.1, for the exact processing steps).

Expects raw data laid out as one folder per domain under the raw path
(see files/README.md for how sample data is uploaded):

```
s3://<bucket>/raw/orders/
s3://<bucket>/raw/customers/
s3://<bucket>/raw/products/
```

Run with, e.g.:

```
spark-submit jobs/process_orders.py \
    --raw-path s3://<bucket>/raw \
    --curated-path s3://<bucket>/curated \
    --redshift-jdbc-url "jdbc:redshift://<redshift-endpoint>:5439/<db>" \
    --redshift-user admin \
    --redshift-password <password>
```
