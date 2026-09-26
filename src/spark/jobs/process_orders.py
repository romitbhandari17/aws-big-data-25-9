"""
PySpark ETL job (Phase 1)

Reads the raw orders, customers, and products data from the S3 data lake
(raw zone), cleans + joins + aggregates it, writes the results back to S3
(curated zone), and loads the aggregated summary into Redshift so it can
be queried there for analytics.

See docs/PROJECT_CONTEXT.md (section 6.1) for the processing steps this
job implements.

Run on EMR, e.g.:
    spark-submit process_orders.py \
        --raw-path s3://<bucket>/raw \
        --curated-path s3://<bucket>/curated \
        --redshift-jdbc-url "jdbc:redshift://<redshift-endpoint>:5439/<db>" \
        --redshift-user admin \
        --redshift-password <password>
"""

import argparse
import logging

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

# Plain stdlib logging is enough here - EMR ships step stdout/stderr to S3
# (log_uri in modules/spark/emr.tf) and shows them in the console's Steps
# tab, so these lines are how progress/errors show up there.
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("orders-etl")


def parse_args():
    """CLI arguments so this job can point at different envs (dev/prod)."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw-path", required=True, help="S3 raw zone, e.g. s3://bucket/raw")
    parser.add_argument("--curated-path", required=True, help="S3 curated zone, e.g. s3://bucket/curated")
    parser.add_argument("--redshift-jdbc-url", required=True, help="Redshift JDBC connection string")
    parser.add_argument("--redshift-user", required=True)
    parser.add_argument("--redshift-password", required=True)
    parser.add_argument("--redshift-table", default="orders_summary", help="Redshift table to load the aggregated result into")
    return parser.parse_args()


def read_raw(spark, raw_path):
    """Read the three raw CSV datasets from the S3 raw zone (one folder per domain)."""
    logger.info("Reading raw orders/customers/products from %s", raw_path)
    orders = spark.read.option("header", True).csv(f"{raw_path}/orders")
    customers = spark.read.option("header", True).csv(f"{raw_path}/customers")
    products = spark.read.option("header", True).csv(f"{raw_path}/products")
    logger.info(
        "Raw row counts - orders=%d customers=%d products=%d",
        orders.count(), customers.count(), products.count(),
    )
    return orders, customers, products


def clean_orders(orders):
    """Fix types, drop duplicate/invalid rows (see PROJECT_CONTEXT.md 6.1 - Data cleaning)."""
    cleaned = (
        orders
        .dropDuplicates(["order_id"])
        .withColumn("amount", F.col("amount").cast("double"))
        .filter(F.col("order_id").isNotNull() & F.col("customer_id").isNotNull())
        .filter(F.col("amount") > 0)
    )
    logger.info("Orders after cleaning: %d rows", cleaned.count())
    return cleaned


def enrich_orders(orders, customers, products):
    """Join orders with customer and product attributes (denormalized view)."""
    enriched = (
        orders
        .join(customers, on="customer_id", how="left")
        .join(products, on="product_id", how="left")
    )
    logger.info("Enriched orders: %d rows", enriched.count())
    return enriched


def aggregate(orders_enriched):
    """Revenue + order-count aggregation by product and customer."""
    summary = (
        orders_enriched
        .groupBy("product_id", "product_name", "category", "customer_id", "customer_name")
        .agg(
            F.sum("amount").alias("total_revenue"),
            F.count("order_id").alias("order_count"),
        )
    )
    logger.info("Aggregated summary: %d rows", summary.count())
    return summary


def main():
    args = parse_args()
    logger.info(
        "Starting orders-etl job: raw_path=%s curated_path=%s redshift_table=%s",
        args.raw_path, args.curated_path, args.redshift_table,
    )
    spark = SparkSession.builder.appName("orders-etl").getOrCreate()

    orders, customers, products = read_raw(spark, args.raw_path)
    orders = clean_orders(orders)
    enriched = enrich_orders(orders, customers, products)
    summary = aggregate(enriched)

    # Curated zone: enriched, row-level orders (reusable by other jobs/queries)
    logger.info("Writing enriched orders to %s/orders_enriched", args.curated_path)
    enriched.write.mode("overwrite").parquet(f"{args.curated_path}/orders_enriched")

    # Curated zone: aggregated summary (kept for auditing what got loaded to Redshift)
    logger.info("Writing summary to %s/orders_summary", args.curated_path)
    summary.write.mode("overwrite").parquet(f"{args.curated_path}/orders_summary")

    # Load the aggregated summary into Redshift for analytical querying.
    # NOTE: a direct JDBC write is used here to keep this first iteration
    # simple. At larger data volumes, prefer staging to S3 and using
    # Redshift's COPY command instead (much faster bulk load).
    logger.info("Loading summary into Redshift table %s", args.redshift_table)
    (
        summary.write
        .format("jdbc")
        .option("url", args.redshift_jdbc_url)
        .option("dbtable", args.redshift_table)
        .option("user", args.redshift_user)
        .option("password", args.redshift_password)
        .mode("overwrite")
        .save()
    )
    logger.info("orders-etl job completed successfully")

    spark.stop()


if __name__ == "__main__":
    main()
