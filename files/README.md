# files/

Dummy sample data for orders, customers, and products — for manual upload
to the S3 data lake **raw zone** (not consumed by Terraform or Spark
directly from here).

Upload each file to its matching raw-zone prefix in the data lake bucket
created by `src/infra/modules/s3`:

```
files/orders.csv    -> s3://<bucket>/raw/orders/orders.csv
files/customers.csv -> s3://<bucket>/raw/customers/customers.csv
files/products.csv  -> s3://<bucket>/raw/products/products.csv
```

The PySpark job in `src/spark/jobs/process_orders.py` expects to read one
CSV folder per domain (`raw/orders/`, `raw/customers/`, `raw/products/`),
which is why each file should be uploaded under its own prefix rather than
directly into `raw/`.

Note: uploading a new file under `raw/orders/` automatically triggers the
full ETL job (S3 event -> Lambda -> EMR step) - see
`src/infra/modules/lambda`. Uploading to `raw/customers/` or
`raw/products/` alone does not trigger a run; upload those first, then
drop/update the orders file last.
