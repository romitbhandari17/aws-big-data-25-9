"""
Lambda handler: triggers the PySpark orders ETL job as an EMR step
whenever a new file lands under the S3 raw zone (Phase 1 orchestration).

Wired up by modules/lambda/lambda.tf as the target of an S3 "ObjectCreated"
event notification scoped to the raw/orders/ prefix. See
docs/PROJECT_CONTEXT.md section 6 for the overall pipeline this feeds.

Config (bucket, cluster id, Redshift connection info, jar/script paths) is
passed in via environment variables set by Terraform, not hardcoded here,
so the same code works across environments (dev/prod).
"""

import os

import boto3

emr = boto3.client("emr")


def handler(event, context):
    """S3 event -> add a spark-submit step to the (already running) EMR cluster."""
    cluster_id = os.environ["EMR_CLUSTER_ID"]
    bucket = os.environ["DATA_LAKE_BUCKET"]
    script_path = os.environ["SPARK_SCRIPT_S3_PATH"]
    redshift_jdbc_driver_path = os.environ["REDSHIFT_JDBC_DRIVER_S3_PATH"]
    redshift_jdbc_url = os.environ["REDSHIFT_JDBC_URL"]
    redshift_user = os.environ["REDSHIFT_USER"]
    redshift_password = os.environ["REDSHIFT_PASSWORD"]
    redshift_table = os.environ.get("REDSHIFT_TABLE", "orders_summary")

    # Re-run the full job (idempotent: raw -> curated -> Redshift overwrite)
    # any time a new file shows up under raw/orders/, rather than trying to
    # process just the single new object - simplest correct behavior for a
    # demo-scale batch job.
    step = {
        "Name": "process-orders-etl",
        "ActionOnFailure": "CONTINUE",
        "HadoopJarStep": {
            "Jar": "command-runner.jar",
            "Args": [
                "spark-submit",
                "--jars",
                redshift_jdbc_driver_path,
                script_path,
                "--raw-path",
                f"s3://{bucket}/raw",
                "--curated-path",
                f"s3://{bucket}/curated",
                "--redshift-jdbc-url",
                redshift_jdbc_url,
                "--redshift-user",
                redshift_user,
                "--redshift-password",
                redshift_password,
                "--redshift-table",
                redshift_table,
            ],
        },
    }

    response = emr.add_job_flow_steps(JobFlowId=cluster_id, Steps=[step])
    print(f"Submitted EMR step {response['StepIds']} to cluster {cluster_id} "
          f"for event: {event.get('Records', [{}])[0].get('s3', {}).get('object', {}).get('key')}")
    return {"stepIds": response["StepIds"]}
