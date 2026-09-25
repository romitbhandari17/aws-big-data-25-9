# Dev environment variable values
#
# Purpose: environment-specific values (e.g., bucket names, cluster sizes)
# passed into the infra/modules when deploying the "dev" environment.

project_name = "aws-big-data-25-9"
aws_region   = "us-east-1"

# Redshift (database) settings for dev
redshift_database_name   = "orders_analytics"
redshift_master_username = "admin"
# NOTE: for a real environment, do NOT commit the password here - pass it
# via an environment variable (TF_VAR_redshift_master_password) or a
# separate untracked *.auto.tfvars file instead. Placeholder only, for demo.
redshift_master_password = "ChangeMe123!"
redshift_node_type       = "dc2.large"
