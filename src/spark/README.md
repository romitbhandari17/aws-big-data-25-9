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

## Redshift JDBC driver

The JDBC writer needs the Redshift driver on Spark's classpath - it's
proprietary and not bundled with EMR/Spark or committed to this repo:

1. Download the driver jar from
   https://docs.aws.amazon.com/redshift/latest/mgmt/jdbc20-download-driver.html
2. Upload it to the data lake bucket, e.g.
   `s3://<bucket>/jars/redshift-jdbc42-2.1.0.30.jar`
3. Pass it to spark-submit with `--jars s3://<bucket>/jars/redshift-jdbc42-2.1.0.30.jar`
   (already wired into the Lambda-submitted step below via the
   `redshift_jdbc_driver_s3_path` Terraform variable).

## Automatic triggering

The job no longer needs to be submitted manually. `src/infra/modules/lambda`
watches the S3 data lake bucket for new objects under `raw/orders/` and
submits this script as an EMR step (`spark-submit`, including `--jars` for
the Redshift driver above) automatically via `emr add-steps`. Manual
submission is still possible for testing:

```
aws emr add-steps --cluster-id <cluster-id> --steps '[{
  "Type": "CUSTOM_JAR",
  "Jar": "command-runner.jar",
  "Args": ["spark-submit", "--jars", "s3://<bucket>/jars/redshift-jdbc42-2.1.0.30.jar",
           "s3://<bucket>/scripts/process_orders.py",
           "--raw-path", "s3://<bucket>/raw",
           "--curated-path", "s3://<bucket>/curated",
           "--redshift-jdbc-url", "jdbc:redshift://<redshift-endpoint>:5439/<db>",
           "--redshift-user", "admin", "--redshift-password", "<password>"]
}]'
```
