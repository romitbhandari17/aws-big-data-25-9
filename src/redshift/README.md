# src/redshift

SQL scripts for Amazon Redshift.

## ddl.sql

Explicit table DDL for the curated `orders_summary` table that
`src/spark/jobs/process_orders.py` loads into Redshift. Spark's JDBC
writer can auto-create this table on first write, but running this DDL
up front makes the schema/types/keys clear for the demo:

```
psql -h <redshift-endpoint> -p 5439 -U admin -d orders_analytics -f ddl.sql
```

Get `<redshift-endpoint>` from the Terraform output `redshift.cluster_endpoint`
(or `redshift.jdbc_url` for the full JDBC connection string).
